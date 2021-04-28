# Multi-Cluster Access and Quota

This example shows how to manage Namespaces, RoleBindings, and ResourcQuotas across multiple clusters using Anthos Config Management, GitOps, and Kustomize.

The resources in this examples are different for each cluster. So ConfigSync is configured to pull config from different directories. If you want your config to be identical for every cluster, check out the [Multi-Cluster Access and Quota](../multi-cluster-access-and-quota/) tutorial instead.

## Namespace management

In this example, each cluster includes the same namespaces. This is not strictly required, but makes it easier to manage a set of clusters.

The namespaces are managed in `config/all-clusters/namespaces.yaml` and inherited using a `kustomization.yaml` file for each cluster.

## Access control

In this example, each namespace includes a RoleBindings to grant view permission to namespace users. 

Following the pattern of [namespace sameness](https://cloud.google.com/anthos/multicluster-management/environs#namespace_sameness), the users are configured to be different for each namespace, but the same across clusters.

The RoleBindings are managed in `config/all-clusters/namespaces/${namespace}/rbac.yaml` and inherited using a `kustomization.yaml` file for each namespace in each cluster.

## Quota management

In this example, each namespace includes a default ResourceQuota with a maximum set for CPU, memory, and pods. 

This default resource is managed in `config/all-clusters/all-namespaces/resource-quota.yaml` and inherited using a `kustomization.yaml` file for each namespace in each cluster.

There is also one example of the default quota being overridden for a specific namespace on a specific cluster, in `config/clusters/cluster-east/namespaces/tenant-a/resource-quota.yaml`.

## Clusters

- **cluster-east** - A multi-zone GKE cluster in the us-east1 region.
- **cluster-west** - A multi-zone GKE cluster in the us-west1 region.

## Filesystem Hierarchy

**Platform Repo (`repos/platform/`):**

```
├── config
│   ├── all-clusters
│   │   ├── all-namespaces
│   │   │   ├── kustomization.yaml
│   │   │   └── resource-quota.yaml
│   │   ├── kustomization.yaml
│   │   ├── namespaces
│   │   │   ├── tenant-a
│   │   │   │   ├── kustomization.yaml
│   │   │   │   └── rbac.yaml
│   │   │   ├── tenant-b
│   │   │   │   ├── kustomization.yaml
│   │   │   │   └── rbac.yaml
│   │   │   └── tenant-c
│   │   │       ├── kustomization.yaml
│   │   │       └── rbac.yaml
│   │   └── namespaces.yaml
│   └── clusters
│       ├── cluster-east
│       │   ├── kustomization.yaml
│       │   └── namespaces
│       │       ├── tenant-a
│       │       │   ├── kustomization.yaml
│       │       │   └── resource-quota.yaml
│       │       ├── tenant-b
│       │       │   └── kustomization.yaml
│       │       └── tenant-c
│       │           └── kustomization.yaml
│       └── cluster-west
│           ├── kustomization.yaml
│           ├── namespaces
│           │   ├── tenant-a
│           │   │   └── kustomization.yaml
│           │   ├── tenant-b
│           │   │   └── kustomization.yaml
│           │   └── tenant-c
│           │       └── kustomization.yaml
│           └── resource-quota.yaml
├── deploy
│   └── clusters
│       ├── cluster-east
│       │   ├── manifest.yaml
│       │   └── namespaces
│       │       ├── tenant-a
│       │       │   └── manifest.yaml
│       │       ├── tenant-b
│       │       │   └── manifest.yaml
│       │       └── tenant-c
│       │           └── manifest.yaml
│       └── cluster-west
│           ├── manifest.yaml
│           └── namespaces
│               ├── tenant-a
│               │   └── manifest.yaml
│               ├── tenant-b
│               │   └── manifest.yaml
│               └── tenant-c
│                   └── manifest.yaml
└── scripts
    └── render.sh
```

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

One way to do that is to change `.spec.git.revision` in the RootSync for each cluster to point to a specific commit SHA or tag. That way, ConfigSync will pull from a specific revision for each cluster, instead of pulling from `HEAD` of the `main` branch everywhere. This method may help protect against complete outage and allow for easy rollbacks, at the cost of a few more commits per rollout.

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

To learn how to manage tenant resources across clusters, follow the [Multi-Cluster Ingress](../multi-cluster-ingress/) tutorial.
