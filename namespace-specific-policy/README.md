# Configuring namespace specific policies

One cluster can be shared between multiple teams. For multi-tenancy, the namespaces used by different teams should have different policies according to the best practices for multi-tenancy.
This doc walks you through the steps for configuring namespace specific policies, such as Role, RoleBinding and NetworkPolicy for a cluster shared between teams.

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

The source Kustomize configurations include one base, three overlays `team-a`, `team-b`, `team-c`, the external resource `external-team` and the external file `external-data`.
Each overlay is a kustomization of the shared `base`.
The difference between different overlays is from two parts:
- Namespace. The configuration inside the directory `configsync-src/example/<TEAM>` is all in the namespace `<TEAM>`.
  This is achieved by adding the namespace directive in `configsync-src/example/<TEAM>/kustomization.yaml`.
  For example, in `configsync-src/example/team-a/kustomization.yaml`:
  ```yaml
  namespace: team-a
  ```

- RoleBinding. For each team, the RoleBinding is for a different Group.
  For example, in `configsync-src/example/team-a`, the RoleBinding is for the group `team-a-admin@mydomain.com`.
  This is achieved by applying the patch file `configsync-src/example/team-a/rolebinding.yaml`.
  So the RoleBinding from the `base` is overwritten.

The folder directory of the `namespace-specific-policy` example:
```
.
├── automated-rendering
│   ├── configsync-src -> ../configsync-src
│   ├── kustomization.yaml
│   └── README.md
├── configsync-src
│   ├── example
│   │   ├── base
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   ├── networkpolicy.yaml
│   │   │   ├── rolebinding.yaml
│   │   │   └── role.yaml
│   │   ├── team-a
│   │   │   └── kustomization.yaml
│   │   ├── team-b
│   │   │   └── kustomization.yaml
│   │   └── team-c
│   │       └── kustomization.yaml
│   ├── external-team
│   │   └── kustomization.yaml
│   └── external-data.txt
├── manual-rendering
│   ├── configsync
│   │   ├── external-team_networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   │   ├── external-team_rbac.authorization.k8s.io_v1_role_team-admin.yaml
│   │   ├── external-team_rbac.authorization.k8s.io_v1_rolebinding_team-admin-rolebinding.yaml
│   │   ├── my-namespace_v1_configmap_my-configmap-5f4h4hkd89.yaml
│   │   ├── team-a_networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   │   ├── team-a_rbac.authorization.k8s.io_v1_role_team-admin.yaml
│   │   ├── team-a_rbac.authorization.k8s.io_v1_rolebinding_team-admin-rolebinding.yaml
│   │   ├── team-b_networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   │   ├── team-b_rbac.authorization.k8s.io_v1_role_team-admin.yaml
│   │   ├── team-b_rbac.authorization.k8s.io_v1_rolebinding_team-admin-rolebinding.yaml
│   │   ├── team-c_networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   │   ├── team-c_rbac.authorization.k8s.io_v1_role_team-admin.yaml
│   │   ├── team-c_rbac.authorization.k8s.io_v1_rolebinding_team-admin-rolebinding.yaml
│   │   ├── v1_namespace_external-team.yaml
│   │   ├── v1_namespace_team-a.yaml
│   │   ├── v1_namespace_team-b.yaml
│   │   └── v1_namespace_team-c.yaml
│   ├── README.md
│   └── scripts
│       └── render.sh
└── README.md
```
