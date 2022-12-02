# Multi-Cluster Anthos Config Management Setup

This tutorial demonstrates how to deploy multiple GKE clusters and install Anthos Config Management on them.

When finished with this tutorial, two GKE clusters will be running in a shared project on a shared network in two different regions with ACM installed and ready to be configured.

The goal of this tutorial is to simplify setup for subsequent tutorials.

## Clusters

- **cluster-east** - A multi-zone GKE cluster in the us-east1 region.
- **cluster-west** - A multi-zone GKE cluster in the us-west1 region.

## Before you begin

**Create or select a project:**

- Replace `<PROJECT_ID>` with the ID of the Project (ex: `example-platform-1234`)
- Replace `<ORG_ID>` with the ID of the Organization (ex: `123456789012`)

These values will be stored in environment variables for later use.

```
PLATFORM_PROJECT_ID="<PROJECT_ID>"
ORGANIZATION_ID="<ORG_ID>"

gcloud projects create "${PLATFORM_PROJECT_ID}" \
    --organization "${ORGANIZATION_ID}"
```

**Enable billing for your project:**

[Learn how to confirm that billing is enabled for your project](https://cloud.google.com/billing/docs/how-to/modify-project).

To link a project to a Cloud Billing account, you need the following permissions: `resourcemanager.projects.createBillingAssignment` on the project (included in `owner`, which you get if you created the project) AND `billing.resourceAssociations.create` on the Cloud Billing account.

- Replace `<BILLING_ACCOUNT_ID>` with the ID of the Cloud Billing account (ex: `AAAAAA-BBBBBB-CCCCCC`)

```
gcloud alpha billing projects link "${PLATFORM_PROJECT_ID}" \
    --billing-account "<BILLING_ACCOUNT_ID>"
```

## Setting up your environment

**Configure your default Google Cloud project ID:**

```
gcloud config set project ${PLATFORM_PROJECT_ID}
```

**Enable required GCP services:**

```
gcloud services enable \
    container.googleapis.com \
    anthos.googleapis.com \
    gkeconnect.googleapis.com \
    gkehub.googleapis.com \
    cloudresourcemanager.googleapis.com
```

**Create or select a network:**

If you have the `compute.skipDefaultNetworkCreation` [organization policy constraint](https://cloud.google.com/resource-manager/docs/organization-policy/org-policy-constraints) enabled, you may have to create a network. Otherwise, just set the `NETWORK` variable for later use.

- Replace `<NETWORK>` with the name of the Network (ex: `default`)

This value will be stored in an environment variable for later use.

```
NETWORK="<NETWORK>"

gcloud compute networks create "${NETWORK}"
```

**Configure firewalls to allow unrestricted internal network traffic:**

If you have the `compute.skipDefaultNetworkCreation` [organization policy constraint](https://cloud.google.com/resource-manager/docs/organization-policy/org-policy-constraints) enabled, you may need to configure this firewall. Otherwise, an equivalent set of firewalls should already be configured on the default network.

```
gcloud compute firewall-rules create allow-all-internal \
    --network ${NETWORK} \
    --allow tcp,udp,icmp \
    --source-ranges 10.0.0.0/8
```

**Deploy Cloud NAT to allow egress from private GKE nodes:**

Because this tutorial provisions clusters with private nodes, those nodes need Cloud NAT configured to allow egress to the internet. To route egress from two subnets in different regions, you need to configure a router for each region.

```
# Create a us-west1 Cloud Router
gcloud compute routers create nat-router-us-west1 \
    --network ${NETWORK} \
    --region us-west1

# Add Cloud NAT to the us-west1 Cloud Router
gcloud compute routers nats create nat-us-west1 \
    --router-region us-west1 \
    --router nat-router-us-west1 \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges \
    --enable-logging

# Create a us-east1 Cloud Router
gcloud compute routers create nat-router-us-east1 \
    --network ${NETWORK} \
    --region us-east1

# Add Cloud NAT to the us-east1 Cloud Router
gcloud compute routers nats create nat-us-east1 \
    --router-region us-east1 \
    --router nat-router-us-east1 \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges \
    --enable-logging
```

**Deploy the GKE clusters:**

The clusters are VPC-native with private nodes, public control planes, Workload Identity enabled, and cluster autoscaling enabled.

For simplicity, this tutorial uses a public control plane. For added security, you may configure private control planes instead, with a more targeted CIDR for authorized networks, but that will require additional VPN or interconnect configuration for you to be able to access the control plane.

```
gcloud container clusters create cluster-west \
    --region us-west1 \
    --network ${NETWORK} \
    --release-channel regular \
    --enable-ip-alias \
    --enable-private-nodes \
    --master-ipv4-cidr 10.64.0.0/28 \
    --enable-master-authorized-networks \
    --master-authorized-networks 0.0.0.0/0 \
    --enable-stackdriver-kubernetes \
    --workload-pool "${PLATFORM_PROJECT_ID}.svc.id.goog" \
    --enable-autoscaling --max-nodes 10 --min-nodes 1 \
    --async

gcloud container clusters create cluster-east \
    --region us-east1 \
    --network ${NETWORK} \
    --release-channel regular \
    --enable-ip-alias \
    --enable-private-nodes \
    --master-ipv4-cidr 10.64.0.16/28 \
    --enable-master-authorized-networks \
    --master-authorized-networks 0.0.0.0/0 \
    --enable-stackdriver-kubernetes \
    --workload-pool "${PLATFORM_PROJECT_ID}.svc.id.goog" \
    --enable-autoscaling --max-nodes 10 --min-nodes 1 \
    --async

# Wait for async operations to complete
while IFS='' read -r line; do
    gcloud container operations wait \
        "$(echo "${line}" | cut -d',' -f1)" \
        --region "$(echo "${line}" | cut -d',' -f2)"
done <<< "$(gcloud container operations list --filter=STATUS!=DONE --format "csv[no-heading](name,zone)")"
```

**Authenticate with cluster-west:**

The context name will be stored in an environment variable for later use.

```
gcloud container clusters get-credentials cluster-west --region us-west1

# set alias for easy context switching
CLUSTER_WEST_CONTEXT=$(kubectl config current-context)
```

**Authenticate with cluster-east:**

The context name will be stored in an environment variable for later use.

```
gcloud container clusters get-credentials cluster-east --region us-east1

# set alias for easy context switching
CLUSTER_EAST_CONTEXT=$(kubectl config current-context)
```

## Register the GKE clusters with Hub

[Hub](https://cloud.google.com/sdk/gcloud/reference/container/hub) is a cluster registry for discovery and feature management. In order to use features like Anthos Config Management and Multi-Cluster Ingress, we first need to register the cluster with Hub.

Registering with Hub will install the Connect Agent on the cluster. To make permission management for the agent easier and more secure, use workload identity mode. If you do not have Workload Identity configured on the clusters, you will need to manage the service accounts, security keys, and IAM policy yourself. For more details, see [Registering a cluster](https://cloud.google.com/anthos/multicluster-management/connect/registering-a-cluster).

**Register a GKE cluster using Workload Identity (recommended):**

```
gcloud container fleet memberships register "cluster-west" \
    --gke-cluster us-west1/cluster-west \
    --enable-workload-identity

gcloud container fleet memberships register "cluster-east" \
    --gke-cluster us-east1/cluster-east \
    --enable-workload-identity
```

## Enable Anthos Config Management

[Anthos Config Management (ACM)](https://cloud.google.com/anthos-config-management/docs/overview) includes an operator that manages the lifecycle of other operators: 
- Config Sync
- Policy Controller
- Binary Authorization
- Hierarchy Controller

These operators are all managed as features using Hub.

**Enable ACM on the Hub:**

```
gcloud beta container fleet config-management enable
```

The ACM Operator will not be installed until one of its components is enabled and configured.

For Config Sync, this requires knowing what repository to pull from. So this will be done in subsequent tutorials.

## Validating success

**Verify expected namespaces exist:**

```
kubectl get ns --context ${CLUSTER_WEST_CONTEXT}
kubectl get ns --context ${CLUSTER_EAST_CONTEXT}
```

Each cluster should have the following namespaces:
- config-management-monitoring
- config-management-system
- default
- gke-connect
- kube-node-lease
- kube-public
- kube-system
- resource-group-system

## Next steps

The clusters you deployed in this tutorial can be used in the following tutorials:
- [Multi-Cluster Fan-out](../multi-cluster-fan-out/)
- [Multi-Cluster Access and Quota](../multi-cluster-access-and-quota/)
- [Multi-Cluster Ingress](../multi-cluster-ingress/)

## Cleaning up

When you've finished with the multi-cluster tutorials, follow these steps to clean up the resources to avoid incurring ongoing charges.

**Delete the GKE clusters:**

Clusters cannot be undeleted with a project, so it's recommended to delete them manually before deleting the project. 
Clusters also generate firewalls which may block network deletion.

```
gcloud container clusters delete cluster-west --region us-west1 --async
gcloud container clusters delete cluster-east --region us-east1 --async

# Wait for async operations to complete
while IFS='' read -r line; do
    gcloud container operations wait \
        "$(echo "${line}" | cut -d',' -f1)" \
        --region "$(echo "${line}" | cut -d',' -f2)"
done <<< "$(gcloud container operations list --filter=STATUS!=DONE --format "csv[no-heading](name,zone)")"
```

**Delete the firewalls:**

If you are not planning to delete the project, but want to delete the network, you must first delete firewalls using the network.

```
gcloud compute firewall-rules list \
    --filter "network=${NETWORK}" \
    --format "table[no-heading](name)" \
    | xargs -n 1 gcloud compute firewall-rules delete
```

**Delete the network:**

If you are not planning to delete the project, but want to re-use it, you may want to delete the network.

```
gcloud compute networks delete ${NETWORK}
```

**Delete the project:**

Deleting the project will delete any resources contained in the project.

```
gcloud projects delete "${PLATFORM_PROJECT_ID}"
```
