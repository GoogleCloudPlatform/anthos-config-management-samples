# Multi-Cluster Anthos Config Management Setup

This tutorial demonstrates how to deploy multiple GKE clusters and install Anthos Config Management on them.

When finished with this tutorial, two GKE clusters will be running in a shared project on a shared network in two different regions and ACM will be ready to configure.

The goal of this tutorial is to simplify setup for subsequent tutorials.

## Clusters

- **cluster-east** - A multi-zone GKE cluster in the us-east1 region.
- **cluster-west** - A multi-zone GKE cluster in the us-west1 region.

## Before you begin

**Create or select a project:**

```
PLATFORM_PROJECT_ID="example-platform-1234"
ORGANIZATION_ID="123456789012"

gcloud projects create "${PLATFORM_PROJECT_ID}" \
    --organization ${ORGANIZATION_ID}
```

**Enable billing for your project:**

[Learn how to confirm that billing is enabled for your project](https://cloud.google.com/billing/docs/how-to/modify-project).

To link a project to a Cloud Billing account, you need `resourcemanager.projects.createBillingAssignment` on the project (included in `owner`, which you get if you created the project) AND `billing.resourceAssociations.create` on the Cloud Billing account.

```
BILLING_ACCOUNT_ID="AAAAAA-BBBBBB-CCCCCC"

gcloud alpha billing projects link "${PLATFORM_PROJECT_ID}" \
    --billing-account ${BILLING_ACCOUNT_ID}
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

```
NETWORK="default"
gcloud compute networks create ${NETWORK}
```

**Configure firewalls to allow unrestricted internal network traffic:**

If you have the `compute.skipDefaultNetworkCreation` [organization policy constraint](https://cloud.google.com/resource-manager/docs/organization-policy/org-policy-constraints) enabled, you may need to configure this firewall. Otherwise, an equivelent set of firewalls should already be configured on the default network.

```
gcloud compute firewall-rules create allow-all-internal \
    --network ${NETWORK} \
    --allow tcp,udp,icmp \
    --source-ranges 10.0.0.0/8
```

**Deploy Cloud NAT to allow egress from private GKE nodes:**

Because this tutorial provisions clusters with private nodes in multiple regions, the subnets the nodes use need Cloud NAT configured to allow egress to the internet.

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

The clusters are VPC-native with private nodes, public control planes, Workload Identity, and cluster autoscaling.

For simplicity, this tutorial uses a public control plane. For added security, you may configure private control planes instead, with a more targetted CIDR for authorized networks, but that will require additional VPN or interconnect configuration for you to be able to access the control plane.

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
    --enable-autoscaling --max-nodes 10 --min-nodes 1

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
    --enable-autoscaling --max-nodes 10 --min-nodes 1
```

**Authenticate with cluster-west:**

```
gcloud container clusters get-credentials cluster-west --region us-west1

# set alias for easy context switching
CLUSTER_WEST_CONTEXT=$(kubectl config current-context)
```

**Authenticate with cluster-east:**

```
gcloud container clusters get-credentials cluster-east --region us-east1

# set alias for easy context switching
CLUSTER_EAST_CONTEXT=$(kubectl config current-context)
```

**Register the clusters with Hub:**

This method for registering with Hub uses Workload Identity, which is prefered from a security standpoint. If you do not have Workload Identity configured on the clusters, you will need to manage the service accounts, security keys, and IAM policy yourself.

```
gcloud container hub memberships register cluster-west \
    --gke-cluster us-west1/cluster-west \
    --enable-workload-identity

gcloud container hub memberships register cluster-east \
    --gke-cluster us-east1/cluster-east \
    --enable-workload-identity
```

**Deploy Anthos Config Management:**

**TODO**: replace manual deploy with `gcloud container hub config-management apply`, once it supports multi-repo.

```
gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml config-management-operator.yaml

kubectl config use-context ${CLUSTER_WEST_CONTEXT}
kubectl apply -f config-management-operator.yaml

kubectl config use-context ${CLUSTER_EAST_CONTEXT}
kubectl apply -f config-management-operator.yaml
```

## Validating success

**Verify expected namespaces exist:**

```
kubectl get ns
```

Should include:
- config-management-monitoring
- config-management-system
- default
- gke-connect
- kube-node-lease
- kube-public
- kube-system
- resource-group-system

## Cleaning up

**Delete the GKE clusters:**

```
gcloud container clusters delete cluster-west --region us-west1
gcloud container clusters delete cluster-east --region us-east1
```

**Delete the network:**

```
gcloud compute networks delete ${NETWORK}
```

**Delete the project:**

```
gcloud projects delete "${PLATFORM_PROJECT_ID}"
```

## Next steps

Follow one of these tutorials:
- [Multi-Cluster Fan-out](../multi-cluster-fan-out/)
- [Multi-Cluster Access and Quota](../multi-cluster-access-and-quota/)
- [Multi-Cluster Ingress](../multi-cluster-ingress/)
- [Multi-Cluster Custom Metric Autoscaling](../multi-cluster-custom-metric-autoscaling/)
