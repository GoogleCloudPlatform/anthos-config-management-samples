
# Structure of a hierarchical root repository

The directory demonstrates how to use a Config Sync hierarchical root repository to
config a Kubernetes cluster shared by two different teams, `team-1` and
`team-2`. 
- Each team has its own Kubernetes namespace, Kubernetes service account, resoure
quotas, network policies, rolebindings.
- The cluster admin sets up a policy in `namespaces/limit-range.yaml` to constrain resource allocations (to Pods or Containers) in both namespaces.
- The cluster admin also sets up ClusterRoles and ClusterRoleBinidngs.

A valid Config Sync hierarchical root repository must include
three subdirectories: `cluster/`, `namespaces/`, and `system/`.

The `cluster/` directory contains configs that apply to entire clusters (such as CRD, ClusterRole, ClusterRoleBinding), rather than to namespaces.

The `namespaces/` directory contains configs for the namespace objects and the
namespace-scoped objects. 
Each subdirectory under
`namespaces/` include the configs for a namespace object and all the
namespace-scoped objects under the namespace. 
The name of a subdirectory  should
be the same as the name of the namespace object. 
Namespace-scoped objects which
need to be created in each namespace, can be put directly under `namespaces/`
(e.g., `namespaces/limit-range.yaml`).

The `system/` directory contains configs for the Config Sync Operator.

```
.
├── cluster
│   ├── clusterrolebinding-namespace-reader.yaml
│   ├── clusterrole-namespace-reader.yaml
│   ├── clusterrole-secret-admin.yaml
│   ├── clusterrole-secret-reader.yaml
│   └── crontab-crd.yaml
├── namespaces
│   ├── limit-range.yaml
│   ├── team-1
│   │   ├── crontab.yaml
│   │   ├── namespace.yaml
│   │   ├── network-policy-default-deny-egress.yaml
│   │   ├── resource-quota-pvc.yaml
│   │   ├── rolebinding-secret-reader.yaml
│   │   └── sa.yaml
│   └── team-2
│       ├── crontab.yaml
│       ├── namespace.yaml
│       ├── network-policy-default-deny-all.yaml
│       ├── resource-quota-pvc.yaml
│       ├── rolebinding-secret-admin.yaml
│       └── sa.yaml
├── README.md
└── system
    └── repo.yaml
```
