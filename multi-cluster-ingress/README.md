# Multi-Cluster Ingress

This tutorial shows how to manage an application with Multi-Cluster Ingress using Anthos Config Management, GitOps, and Kustomize.

This tutorial is based on [Deploying Ingress across clusters](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress), except it uses ConfigSync and kustomize to deploy to multiple multi-tenant clusters.

In addition, this tutorial shows how to use the Kustomize configuration from [Multi-Cluster Access and Quota](../multi-cluster-access-and-quota/) to manage cluster resources seperately from namespace resources, which is useful if you have a platform team managing clusters for seperate application teams.

![Architecture Diagram](docs/architecture.png)

# Goals

This usage of Multi-Cluster Ingress serves multiple goals:

By using backends on multiple clusters in different regions, each with nodes in multiple zones, and a single global Virtual IP, the application can reach very **high availability**.

By using backends on multiple clusters in different regions and Google's global [Cloud Load Balancer](https://cloud.google.com/load-balancing/docs/load-balancing-overview), which automatically routes traffic based on latency, availability, and capacity, the application can have very **low latency** for clients in different parts of the world.

By using backends on multiple clusters, the application can reach very **high scale**, beyond that which can be supported by a single cluster.

## Clusters

- **cluster-east** - A multi-zone GKE cluster in the us-east1 region.
- **cluster-west** - A multi-zone GKE cluster in the us-west1 region.

## Tenant Workloads

This tutorial demonstrates one tenant with a workload that span multiple clusters:

- **zoneprinter** - an echo service behind Multi-Cluster Ingress

## Filesystem Hierarchy

**Platform Repo (`repos/platform/`):**

```
├── configsync
│   └── clusters
│       ├── cluster-east
│       │   └── v1_namespace_zoneprinter.yaml
│       └── cluster-west
│           └── v1_namespace_zoneprinter.yaml
├── configsync-src
│   ├── all-clusters
│   │   ├── kustomization.yaml
│   │   └── namespaces.yaml
│   └── clusters
│       ├── cluster-east
│       │   └── kustomization.yaml
│       └── cluster-west
│           └── kustomization.yaml
└── scripts
    └── render.sh
```

**ZonePrinter Repo (`repos/zoneprinter/`):**

```
├── configsync
│   └── clusters
│       ├── cluster-east
│       │   └── namespaces
│       │       └── zoneprinter
│       │           └── apps_v1_deployment_zoneprinter.yaml
│       └── cluster-west
│           └── namespaces
│               └── zoneprinter
│                   ├── apps_v1_deployment_zoneprinter.yaml
│                   ├── networking.gke.io_v1_multiclusteringress_zoneprinter.yaml
│                   └── networking.gke.io_v1_multiclusterservice_zoneprinter.yaml
├── configsync-src
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
└── scripts
    └── render.sh
```

# Config Cluster

In this tutorial, the `cluster-west` cluster will be used as the [config cluster](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress-setup#specifying_a_config_cluster) for Multi-cluster Ingress. The [MultiClusterIngress](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress#multiclusteringress_spec) and [MultiClusterService](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress#multiclusterservice_spec) resources in the `mci.yaml` file are only being deployed to the `cluster-west` cluster.

In a production environment, it may be desirable to use a third cluster as the config cluster, to reduce the risk that the config cluster is unavailable to make multi-cluster changes, but in this case we're using one of the two workload clusters in order to reduce costs.

## Kustomize

In this tutorial, some resources differ between namespaces and clusters.

Because of this, the resources specific to each cluster and the same on each cluster are managed in different places and merged together using Kustomize. Likewise, the resources specific to each namespace and the same in each namespace are managed in different places and merged together using Kustomize. This is not strictly required, but it may help reduce the risk of misconfiguration between clusters and make it easier to roll out changes consistently.

Kustomize is also being used here to add additional labels, to aid observability.

To invoke Kustomize, execute `scripts/render.sh` to render the resources under `configsync-src/` and write them to `configsync/`.

If you don't want to use Kustomize, just use the resources under the `configsync/` directory and delete the `configsync-src/` and `scripts/render.sh` script.

## ConfigSync

This tutorial installs ConfigSync on two clusters and configures them to pull config from different `configsync/clusters/${cluster-name}/` directories in the same Git repository.

## Progressive rollouts

This tutorial demonstrates the deployment of resources to multiple clusters at the same time. In a production environment, you may want to reduce the risk of rolling out changes by deploying to each cluster individually and/or by deploying to a staging environment first.

One way to do that is to change the field `spec.git.revision` in the [RootSync](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/multi-repo#root-sync) resource for each cluster to point to a specific commit SHA or tag. That way, both clusters will pull from a specific revision, instead of both pulling from `HEAD` of the `main` branch. This method may help protect against complete outage and allow for easy rollbacks, at the cost of a few more commits per rollout.

To read more about progressive delivery patterns, see [Safe rollouts with Anthos Config Management](https://cloud.google.com/architecture/safe-rollouts-with-anthos-config-management).

## Before you begin

1. Follow the [Multi-Cluster Anthos Config Management Setup](./multi-cluster-acm-setup/) tutorial to deploy two GKE clusters and install ACM.

## Create a Git repository for platform config

[Github: Create a repo](https://docs.github.com/en/github/getting-started-with-github/create-a-repo)

```
PLATFORM_REPO="https://github.com/USER_NAME/REPO_NAME/"
```

**Select or create a local workspace directory:**

Since you will need to clone multiple repos for this tutorial, select a directory to contain them.

- Replace `<WORKSPACE>` with the name of the desired workspace directory (ex: `~/workspace`)

This value will be stored in an environment variable for later use.

```
WORKSPACE="<WORKSPACE>"

mkdir -p "${WORKSPACE}"
```

**Clone the tutorial repo:**

```
cd "${WORKSPACE}"

git clone https://github.com/GoogleCloudPlatform/anthos-config-management-samples.git
```

**Clone the platform repo:**

```
cd "${WORKSPACE}"

git clone "${PLATFORM_REPO}" platform
```

**Copy the platform config from the tutorial repo:**

```
cd "${WORKSPACE}"

cp -r anthos-config-management-samples/multi-cluster-ingress/repos/platform/* platform/
```

**Push the platform config to the platform repo:**

```
cd "${WORKSPACE}/platform/"

git add .

git commit -m "initialize platform config"

git push
```

## Create a Git repository for ZonePrinter config

[Github: Create a repo](https://docs.github.com/en/github/getting-started-with-github/create-a-repo)

```
ZONEPRINTER_REPO="https://github.com/USER_NAME/REPO_NAME/"
```

**Clone the zoneprinter repo:**

```
cd "${WORKSPACE}"

git clone "${PLATFORM_REPO}" zoneprinter
```

**Copy the zoneprinter config from the tutorial repo:**

```
cd "${WORKSPACE}"

cp -r anthos-config-management-samples/multi-cluster-ingress/repos/zoneprinter/* zoneprinter/
```

**Push the zoneprinter config to the zoneprinter repo:**

```
cd "${WORKSPACE}/zoneprinter/"

git add .

git commit -m "initialize zoneprinter config"

git push
```

# Enable Multi-Cluster Ingress via Hub

```
gcloud alpha container hub ingress enable \
    --config-membership projects/${PROJECT}/locations/global/memberships/cluster-west
```

This configures cluster-west as the cluster to manage `MultiClusterIngress` and `MultiClusterService` resources for the Environ.

## Configure Anthos Config Management for platform config

[Anthos Config Management (ACM)](https://cloud.google.com/anthos-config-management/docs/overview) is used to install ConfigSync. ConfigSync can then be configured using the `RootSync` and `RepoSync` resources.

`RootSync` can be used to manage any cluster resource, including both cluster-scoped and namespace-scoped resources. Only on `RootSync` is allowed per cluster.

`RepoSync` can be used to manage resources in a single namespace. ConfigSync supports one `RepoSync` per namespace.

**Configure ACM using kubectl (recommended):**

If you installed ACM using kubectl, you must also configure `ConfigManagement` using kubectl.

```
kubectl apply --context ${CLUSTER_WEST_CONTEXT} -f - << EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  clusterName: cluster-west
  enableMultiRepo: true
EOF

kubectl apply --context ${CLUSTER_EAST_CONTEXT} -f - << EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  clusterName: cluster-east
  enableMultiRepo: true
EOF
```

**Wait for the RootSync CRD to be created:**

The ACM installer also installs the RootSync Custom Resource Definition (CRD).
The next apply command will fail if the RootSync CRD is not available yet.
This process should only take a few seconds.

**Configure RootSync using kubectl (recommended):**

If you installed ACM using kubectl, you must also configure `RootSync` using kubectl.

```
kubectl apply --context ${CLUSTER_WEST_CONTEXT} -f - << EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: ${PLATFORM_REPO}
    branch: main
    revision: HEAD
    dir: "configsync/clusters/cluster-west"
    auth: none
EOF

kubectl apply --context ${CLUSTER_EAST_CONTEXT} -f - << EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: ${PLATFORM_REPO}
    branch: main
    revision: HEAD
    dir: "configsync/clusters/cluster-east"
    auth: none
EOF
```

**Configure ACM and RootSync using Hub:**

If you installed ACM using Hub, you must also configure `ConfigManagement` using Hub.

When using Hub to manage ACM configuration, the `RootSync` resource will automatically be generated using the legacy configuration syntax in the `ConfigManagement` resource.

```
cat > config-management-west.yaml << EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  sourceFormat: unstructured
  git:
    syncRepo: ${PLATFORM_REPO}
    syncBranch: main
    syncRev: HEAD
    policyDir: "configsync/clusters/cluster-west"
    secretType: none
EOF

gcloud alpha container hub config-management apply \
  --membership "cluster-west" \
  --config config-management-west.yaml

cat > config-management-east.yaml << EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  sourceFormat: unstructured
  git:
    syncRepo: ${PLATFORM_REPO}
    syncBranch: main
    syncRev: HEAD
    policyDir: "configsync/clusters/cluster-east"
    secretType: none
EOF

gcloud alpha container hub config-management apply \
  --membership "cluster-east" \
  --config config-management-east.yaml
```

**TODO**: Validate `gcloud alpha container hub config-management apply` supports ConfigSync multi-repo.

## Configure Anthos Config Management for zoneprinter config

Unlike `RootSync` resources, which bootstrap GitOps for each cluster, `RepoSync` resources can themselves be managed by GitOps along with the rest of the cluster config.

```
cd "${WORKSPACE}/platform/"

mkdir -p configsync-src/clusters/cluster-west/namespaces/zoneprinter/

cat > configsync-src/clusters/cluster-west/namespaces/zoneprinter/repo-sync.yaml < EOF
apiVersion: configsync.gke.io/v1beta1
kind: RepoSync
metadata:
  name: repo-sync
  namespace: zoneprinter
spec:
  sourceFormat: unstructured
  git:
    repo: ${ZONEPRINTER_REPO}
    branch: main
    revision: HEAD
    dir: "configsync/clusters/cluster-west/namespaces/zoneprinter"
    auth: none
EOF

mkdir -p configsync-src/clusters/cluster-east/namespaces/zoneprinter/

cat > configsync-src/clusters/cluster-east/namespaces/zoneprinter/repo-sync.yaml < EOF
apiVersion: configsync.gke.io/v1beta1
kind: RepoSync
metadata:
  name: repo-sync
  namespace: zoneprinter
spec:
  sourceFormat: unstructured
  git:
    repo: ${ZONEPRINTER_REPO}
    branch: main
    revision: HEAD
    dir: "configsync/clusters/cluster-east/namespaces/zoneprinter"
    auth: none
EOF

git add .

git commit -m "add zoneprinter repo-sync"

git push
```

## Validating success

**Lookup latest commit SHA:**

```
(cd "${WORKSPACE}/platform/" && git log -1 --oneline)

(cd "${WORKSPACE}/zoneprinter/" && git log -1 --oneline)
```

**Wait for config to be deployed:**

```
nomos status --contexts ${CLUSTER_WEST_CONTEXT},${CLUSTER_EAST_CONTEXT}
```

Should say "SYNCED" for both clusters with the latest commit SHA.

**Verify expected namespaces exist:**

```
kubectl get ns --context ${CLUSTER_WEST_CONTEXT}

kubectl get ns --context ${CLUSTER_EAST_CONTEXT}
```

Should include (non-exclusive):
- zoneprinter

**Verify expected resource exist:**

```
kubectl get Deployment,MultiClusterIngress,MultiClusterService -n zoneprinter --context ${CLUSTER_WEST_CONTEXT}

kubectl get Deployment -n zoneprinter --context ${CLUSTER_EAST_CONTEXT}
```

Should include (non-exclusive):
- deployment.apps/zoneprinter (both clusters)
- multiclusteringress.networking.gke.io/zoneprinter (cluster-west only)
- multiclusterservice.networking.gke.io/zoneprinter (cluster-west only)

**Poll the ingress endpoint to see which cluster responds:**

```
INGRESS_ENDPOINT=$(TODO)

for i in {1..100}; do curl ${INGRESS_ENDPOINT}; done
```

## Cleaning up

If you plan to follow more multi-cluster tutorials, you can clean up these clusters with the following steps. Otherwise, follow the Clean up instructions on the [Setup](../multi-cluster-acm-setup/) tutorial to delete the clusters, network, and project.

**Delete the zoneprinter config in the zoneprinter repo:**

```
cd "${WORKSPACE}/zoneprinter/"

rm -rf ./*

git add .

git commit -m "delete zoneprinter config"

git push
```

**Lookup latest commit SHA:**

```
git log -1 --oneline
```

**Wait for config to be synchronized:**

```
nomos status --contexts ${CLUSTER_WEST_CONTEXT},${CLUSTER_EAST_CONTEXT}
```

Should say "SYNCED" for both clusters with the latest commit SHA.

**Delete the platform config in the platform repo:**

```
cd "${WORKSPACE}/platform/"

rm -rf ./*

git add .

git commit -m "delete platform config"

git push
```

**Lookup latest commit SHA:**

```
git log -1 --oneline
```

**Wait for config to be synchronized:**

```
nomos status --contexts ${CLUSTER_WEST_CONTEXT},${CLUSTER_EAST_CONTEXT}
```

Should say "SYNCED" for both clusters with the latest commit SHA.

**Delete the ACM resources with kubectl (recommended):**

If you installed ACM with kubectl, the `RootSync` and `ConfigManagement` resources must also be deleted with kubectl.

```
kubectl delete RootSync,ConfigManagement --all --context ${CLUSTER_WEST_CONTEXT}
kubectl delete RootSync,ConfigManagement --all --context ${CLUSTER_EAST_CONTEXT}
```

**Delete the ACM resources with Hub:**

If you installed ACM with Hub, the `RootSync` and `ConfigManagement` resources must also be deleted with Hub.

```
gcloud alpha container hub config-management delete --membership "cluster-west"
gcloud alpha container hub config-management delete --membership "cluster-east"
```

**Delete the zoneprinter repo:**

[Github: Deleting a repository](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/archiving-a-github-repository)

```
rm -rf "${WORKSPACE}/zoneprinter/"
```

**Delete the platform repo:**

[Github: Deleting a repository](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/archiving-a-github-repository)

```
rm -rf "${WORKSPACE}/platform/"
```
