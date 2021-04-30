# Multi-Cluster Fan-out

This tutorial shows how to manage Namespaces, RoleBindings, and ResourceQuotas across multiple clusters using Anthos Config Management and GitOps.

The resources in this tutorial are identical across both clusters. So ConfigSync is configured to pull config from the same directory. If you want your config to be different for every cluster, check out the [Multi-Cluster Access and Quota](../multi-cluster-access-and-quota/) tutorial instead.

## Clusters

- **cluster-east** - A multi-zone GKE cluster in the us-east1 region.
- **cluster-west** - A multi-zone GKE cluster in the us-west1 region.

## Filesystem Hierarchy

**Platform Repo (`repos/platform/`):**

```
└── deploy
    └── all-clusters
        ├── namespaces
        │   ├── tenant-a
        │   │   ├── quota.yaml
        │   │   └── rbac.yaml
        │   ├── tenant-b
        │   │   ├── quota.yaml
        │   │   └── rbac.yaml
        │   └── tenant-c
        │       ├── quota.yaml
        │       └── rbac.yaml
        └── namespaces.yaml
```

## Access Control

This tutorial includes RoleBindings in each namespace to grant view permission to namespace users.

The users are configured to be different for each namespace, but the same across clusters.

## Progressive rollouts

This tutorial demonstrates the deployment of resources to multiple clusters at the same time. In a production environment, you may want to reduce the risk of rolling out changes by deploying to each cluster individually and/or by deploying to a staging environment first.

One way to do that is to change `.spec.git.revision` in the RootSync for each cluster to point to a specific commit SHA or tag. That way, both clusters will pull from a specific revision, instead of both pulling from `HEAD` of the `main` branch. This method may help protect against complete outage and allow for easy rollbacks, at the cost of a few more commits per rollout.

Another option is to seperate the configuration for each cluster into different directories. See [Multi-Cluster Resource Management](../multi-cluster-resource-management) for an example of this pattern.

To read more about progressive delivery patterns, see [Safe rollouts with Anthos Config Management](https://cloud.google.com/architecture/safe-rollouts-with-anthos-config-management).

## ConfigSync

This tutorial installs ConfigSync on two clusters and configures them both to pull config from the same `deploy/all-clusters/` directory in the same Git repository.

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

## Configure Anthos Config Management

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

**Wait a few seconds for ConfigManagement to install the RootSync CRD.**

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
    dir: "deploy/all-clusters"
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
    dir: "deploy/all-clusters"
    auth: none
EOF
```

**Configure ACM and RootSync using Hub:**

If you installed ACM using Hub, you must also configure `ConfigManagement` using Hub.

When using Hub to manage ACM configuration, the `RootSync` resource will automatically be generated using the legacy configuration syntax in the `ConfigManagement` resource.

```
cat > config-management.yaml << EOF
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
    policyDir: "deploy/all-clusters"
    secretType: none
EOF

gcloud alpha container hub config-management apply \
  --membership "cluster-west" \
  --config config-management.yaml

gcloud alpha container hub config-management apply \
  --membership "cluster-east" \
  --config config-management.yaml
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
- tenant-a
- tenant-b
- tenant-c

**Verify expected resource exist:**

```
kubectl config use-context ${CLUSTER_EAST_CONTEXT}
kubectl get ResourceQuota,RoleBinding -n tenant-a
kubectl get ResourceQuota,RoleBinding -n tenant-b
kubectl get ResourceQuota,RoleBinding -n tenant-c


kubectl config use-context ${CLUSTER_WEST_CONTEXT}
kubectl get ResourceQuota,RoleBinding -n tenant-a
kubectl get ResourceQuota,RoleBinding -n tenant-b
kubectl get ResourceQuota,RoleBinding -n tenant-c
```

Should include (non-exclusive):
- resourcequota/default
- rolebinding.rbac.authorization.k8s.io/namespace-viewer

## Cleaning up

Follow the Clean up instructions on the [Setup](../multi-cluster-acm-setup/) tutorial to delete the clusters, network, and project.

## Next steps

To learn how to manage resources seperately for each cluster, follow the [Multi-Cluster Access and Quota](../multi-cluster-access-and-quota/) tutorial.
