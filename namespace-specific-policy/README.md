# Configuring namespace specific policies

One cluster can be shared between multiple tenants. For multi-tenancy, the namespaces used by different tenants should have different policies according to the best practices for multi-tenancy.
This doc walks you through the steps for configuring namespace specific policies, such as Role, RoleBinding and NetworkPolicy for a cluster shared between tenants.

This example provides two different ways of rendering and syncing your configurations
- **[manual rendering](manual-rendering/README.md)**:
  this option requires you to render the configurations using the Kustomize CLI manually,
  and check in the rendered configurations to your Git repository.
  Config Sync will sync from the rendered output directly.
- **[automated rendering](automated-rendering/README.md)**:
  Config Sync supports rendering Kustomize configurations in version 1.9.0 or later.
  You can check in the Kustomize configurations to your Git repository,
  and Config Sync will render and sync them to your clusters.

## Source Kustomize configurations

The directory `configsync-src` contains the configuration in Kustomize format.

The manual rendering method and the automated rendering method shares the same source Kustomize configurations.

The source Kustomize configurations include one base and three overlays `tenant-a`, `tenant-b` and `tenant-c`.
Each overlay is a customization of the shared `base`.
The difference between different overlays is from two parts:
- Namespace. The configuration inside the directory `configsync-src/<TENANT>` is all in the namespace `<TENANT>`.
  This is achieved by adding the namespace directive in `configsync-src/<TENANT>/kustomization.yaml`.
  For example, in `configsync-src/tenant-a/kustomization.yaml`:
  ```yaml
  namespace: tenant-a
  ```

- RoleBinding. For each tenant, the RoleBinding is for a different Group.
  For example, in `configsync-src/tenant-a`, the RoleBinding is for the group `tenant-a-admin@mydomain.com`.
  This is achieved by applying the patch file `configsync-src/tenant-a/rolebinding.yaml`.
  So the RoleBinding from the `base` is overwritten.

The folder directory of the `namespace-specific-policy` example:
```
.
├── automated-rendering
│   ├── configsync-src -> ../configsync-src
│   ├── kustomization.yaml
│   └── README.md
├── configsync-src
│   ├── base
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── networkpolicy.yaml
│   │   ├── rolebinding.yaml
│   │   └── role.yaml
│   ├── tenant-a
│   │   └── kustomization.yaml
│   ├── tenant-b
│   │   └── kustomization.yaml
│   └── tenant-c
│       └── kustomization.yaml
├── manual-rendering
│   ├── configsync
│   │   ├── tenant-a
│   │   │   ├── networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   │   │   ├── rbac.authorization.k8s.io_v1_rolebinding_tenant-admin-rolebinding.yaml
│   │   │   ├── rbac.authorization.k8s.io_v1_role_tenant-admin.yaml
│   │   │   └── v1_namespace_tenant-a.yaml
│   │   ├── tenant-b
│   │   │   ├── networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   │   │   ├── rbac.authorization.k8s.io_v1_rolebinding_tenant-admin-rolebinding.yaml
│   │   │   ├── rbac.authorization.k8s.io_v1_role_tenant-admin.yaml
│   │   │   └── v1_namespace_tenant-b.yaml
│   │   ├── tenant-c
│   │   │   ├── networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   │   │   ├── rbac.authorization.k8s.io_v1_rolebinding_tenant-admin-rolebinding.yaml
│   │   │   ├── rbac.authorization.k8s.io_v1_role_tenant-admin.yaml
│   │   │   └── v1_namespace_tenant-c.yaml
│   ├── README.md
│   └── scripts
│       └── render.sh
└── README.md
```
