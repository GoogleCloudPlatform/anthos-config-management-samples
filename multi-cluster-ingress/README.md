# Multi-Cluster Ingress

This example shows how to manage an application with Multi-Cluster Ingress using Anthos Config Management, GitOps, and Kustomize.

This example is based on [Deploying Ingress across clusters](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress), except it uses ConfigSync and kustomize to deploy to multiple multi-tenant clusters.

In addition, this example shows how to use the Kustomize configuration from [Multi-Cluster Access and Quota](../multi-cluster-access-and-quota/) to manage cluster resources seperately from namespace resources, which is useful if you have a platform team managing clusters for seperate application teams.

# Goals

This usage of Multi-Cluster Ingress serves multiple goals:

By using backends on multiple clusters in different regions, each with nodes in multiple zones, and a single global Virtual IP, the application can reach very **high availability**.

By using backends on multiple clusters in different regions and Google's global [Cloud Load Balancer](https://cloud.google.com/load-balancing/docs/load-balancing-overview), which automatically routes traffic based on latency, availability, and capacity, the application can have very **low latency** for clients in different parts of the world.

By using backends on multiple clusters, the application can reach very **high scale**, beyond that which can be supported by a single cluster.

## Clusters

- **cluster-east** - A multi-zone GKE cluster in the us-east1 region.
- **cluster-west** - A multi-zone GKE cluster in the us-west1 region.

## Tenant Workloads

This example demonstrates one tenant with a workload that span multiple clusters:

- **zoneprinter** - an echo service behind Multi-Cluster Ingress

## Filesystem Hierarchy

**Platform Repo (`repos/platform/`):**

```
├── config
│   ├── all-clusters
│   │   ├── kustomization.yaml
│   │   └── namespaces.yaml
│   └── clusters
│       ├── cluster-east
│       │   └── kustomization.yaml
│       └── cluster-west
│           └── kustomization.yaml
├── deploy
│   └── clusters
│       ├── cluster-east
│       │   └── rendered.yaml
│       └── cluster-west
│           └── rendered.yaml
└── scripts
    └── render.sh
```

**ZonePrinter Repo (`repos/zoneprinter/`):**

```
├── config
│   ├── all-clusters
│   │   └── namespaces
│   │       └── zoneprinter
│   │           ├── kustomization.yaml
│   │           └── zoneprinter-deployment.yaml
│   └── clusters
│       ├── cluster-east
│       │   └── namespaces
│       │       └── zoneprinter
│       │           └── kustomization.yaml
│       └── cluster-west
│           └── namespaces
│               └── zoneprinter
│                   ├── kustomization.yaml
│                   └── mci.yaml
├── deploy
│   └── clusters
│       ├── cluster-east
│       │   └── namespaces
│       │       └── zoneprinter
│       │           └── rendered.yaml
│       └── cluster-west
│           └── namespaces
│               └── zoneprinter
│                   └── rendered.yaml
└── scripts
    └── render.sh
```

# Config Cluster

In this example, the `cluster-west` cluster will be used as the [config cluster](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress-setup#specifying_a_config_cluster) for Multi-cluster Ingress. The [MultiClusterIngress](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress#multiclusteringress_spec) and [MultiClusterService](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress#multiclusterservice_spec) resources in the `mci.yaml` file are only being deployed to the `cluster-west` cluster.

In a production environment, it may be desirable to use a third cluster as the config cluster, to reduce the risk that the config cluster is unavailable to make multi-cluster changes, but in this case we're using one of the two workload clusters in order to reduce costs.

## Kustomize

In this example, some resources differ between namespaces and clusters.

Because of this, the resources specific to each cluster and the same on each cluster are managed in different places and merged together using Kustomize. Likewise, the resources specific to each namespace and the same in each namespace are managed in different places and merged together using Kustomize. This is not strictly required, but it may help reduce the risk of misconfiguration between clusters and make it easier to roll out changes consistently.

Kustomize is also being used here to add additional labels, to aid observability.

To invoke Kustomize, execute `scripts/render.sh` to render the resources under `config/` and write them to `deploy/`.

If you don't want to use Kustomize, just use the resources under the `deploy/` directory and delete the `config/` and `scripts/render.sh` script.

## ConfigSync

This example installs ConfigSync on two clusters and configures them to pull config from different `deploy/clusters/${cluster-name}/` directories in the same Git repository.

## Progressive rollouts

This example demonstrates the deployment of resources to multiple clusters at the same time. In a production environment, you may want to reduce the risk of rolling out changes by deploying to each cluster individually and/or by deploying to a staging environment first.

One way to do that is to change `.spec.git.revision` in the RootSync for each cluster and RepoSync for each namespace to point to a specific commit SHA or tag. That way, ConfigSync will pull from a specific revision for each cluster and namespace, instead of pulling from `HEAD` of the `main` branch everywhere. This method may help protect against complete outage and allow for easy rollbacks, at the cost of a few more commits per rollout.

To read more about progressive delivery patterns, see [Safe rollouts with Anthos Config Management](https://cloud.google.com/architecture/safe-rollouts-with-anthos-config-management).

## Before you begin

1. Follow the [Multi-Cluster Anthos Config Management Setup](./multi-cluster-acm-setup/) tutorial to deploy two GKE clusters and install ACM.

## Create a Git repository for Platform config

[Github: Create a repo](https://docs.github.com/en/github/getting-started-with-github/create-a-repo)

```
PLATFORM_REPO="https://github.com/USER_NAME/REPO_NAME/"
```

**Push platform config to the PLATFORM_REPO:**

```
mkdir -p .github/
cd .github/

git clone "${PLATFORM_REPO}" platform

cp -r ../repos/platform/* platform/

cd platform/

git add .

git commit -m "initialize platform config"

git push

cd ../..
```

## Create a Git repository for ZonePrinter config

[Github: Create a repo](https://docs.github.com/en/github/getting-started-with-github/create-a-repo)

```
ZONEPRINTER_REPO="https://github.com/USER_NAME/REPO_NAME/"
```

**Push zoneprinter config to the ZONEPRINTER_REPO:**

```
mkdir -p .github/
cd .github/

git clone "${ZONEPRINTER_REPO}" zoneprinter

cp -r ../repos/zoneprinter/* zoneprinter/

cd zoneprinter/

git add .

git commit -m "initialize zoneprinter config"

git push

cd ../..
```

# Enable Multi-Cluster Ingress via Hub

```
gcloud alpha container hub ingress enable \
    --config-membership projects/${PROJECT}/locations/global/memberships/cluster-west
```

This configures cluster-west as the cluster to manage MultiClusterIngress and MultiClusterService resources for the Environ.

## Configure Anthos Config Management for platform config

```
kubectl config use-context ${CLUSTER_WEST_CONTEXT}

kubectl apply -f - << EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  clusterName: cluster-west
  enableMultiRepo: true
EOF

# Wait a few seconds for ConfigManagement to install the RootSync CRD

kubectl apply -f - << EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: ${PLATFORM_REPO}
    revision: HEAD
    branch: main
    dir: "deploy/clusters/cluster-west"
    auth: none
EOF

kubectl config use-context ${CLUSTER_EAST_CONTEXT}

kubectl apply -f - << EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  clusterName: cluster-east
  enableMultiRepo: true
EOF

# Wait a few seconds for ConfigManagement to install the RootSync CRD

kubectl apply -f - << EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: ${PLATFORM_REPO}
    revision: HEAD
    branch: main
    dir: "deploy/clusters/cluster-east"
    auth: none
EOF
```

## Configure Anthos Config Management for zoneprinter config

```
cd .github/platform/

mkdir -p config/clusters/cluster-west/namespaces/zoneprinter/

cat > config/clusters/cluster-west/namespaces/zoneprinter/repo-sync.yaml < EOF
apiVersion: configsync.gke.io/v1beta1
kind: RepoSync
metadata:
  name: repo-sync
  namespace: zoneprinter
spec:
  sourceFormat: unstructured
  git:
    repo: ${ZONEPRINTER_REPO}
    revision: HEAD
    branch: main
    dir: "deploy/clusters/cluster-west/namespaces/zoneprinter"
    auth: none
EOF

mkdir -p config/clusters/cluster-west/namespaces/zoneprinter/

cat > config/clusters/cluster-east/namespaces/zoneprinter/repo-sync.yaml < EOF
apiVersion: configsync.gke.io/v1beta1
kind: RepoSync
metadata:
  name: repo-sync
  namespace: zoneprinter
spec:
  sourceFormat: unstructured
  git:
    repo: ${ZONEPRINTER_REPO}
    revision: HEAD
    branch: main
    dir: "deploy/clusters/cluster-east/namespaces/zoneprinter"
    auth: none
EOF

git add .

git commit -m "add zoneprinter repo-sync"

git push

cd ../..
```

## Validating success

**Lookup latest commit SHA:**

```
(cd .github/platform/ && git log -1 --oneline)
```

**Wait for config to be deployed:**

```
nomos status
```

Should say "SYNCED" for both clusters with the latest commit SHA.

**Verify expected namespaces exist:**

```
kubectl config use-context ${CLUSTER_EAST_CONTEXT}
kubectl get ns

kubectl config use-context ${CLUSTER_WEST_CONTEXT}
kubectl get ns
```

Should include (non-exclusive):
- zoneprinter

**Verify expected resource exist:**

```
kubectl config use-context ${CLUSTER_EAST_CONTEXT}
kubectl get Deployment -n zoneprinter


kubectl config use-context ${CLUSTER_WEST_CONTEXT}
kubectl get Deployment,MultiClusterIngress,MultiClusterService -n zoneprinter
```

Should include (non-exclusive):
- TODO

**Poll the ingress endpoint to see which cluster responds:**

```
INGRESS_ENDPOINT=$(TODO)

for i in {1..100}; do curl ${INGRESS_ENDPOINT}; done
```

## Cleaning up

Follow the Clean up instructions on the [Setup](../multi-cluster-acm-setup/) tutorial to delete the clusters, network, and project.
