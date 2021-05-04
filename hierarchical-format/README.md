# Config Sync Hierarchical Root Repository Example - Basic Cluster Configuration

This example shows how a cluster admin can use a Config Sync hierarchical root repository to manage the configuration of a
Kubernetes cluster shared by two different teams, `team-1` and `team-2`.
The cluster configuration is under the `config/` directory.

The `compiled/` directory (which is not required for using Config Sync) contains the output of `nomos hydrate`, which compiles
the configs under the `config/` directory to the exact form that would be sent to the APIServer to apply.

## Before you begin

- You’ll need a cluster that has Config Sync installed.
  Please follow the [instructions](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/installing)
  to install Config Sync if it is not set up yet.
- [Install the `nomos` command](https://cloud.devsite.corp.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/nomos-command#installing)


## Sync the root repository

This root repository can be synced using Config Sync either in the mono-repo mode or in the multi-repo mode.

### Sync the root repository using Config Sync in the mono-repo mode

To sync the root repository using Config Sync in the mono-repo mode, the cluster admin should follow the follow steps:

Step 1: create a file named `config-management.yaml` with a `ConfigManagement` custom resource:

```yaml
# config-management.yaml
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  git:
    syncRepo: https://github.com/GoogleCloudPlatform/anthos-config-management-samples/
    syncBranch: init
    policyDir: hierarchical-format/config
    secretType: none
  sourceFormat: hierarchy
```

Step 2: apply the `ConfigManagement` CR:
```
kubectl apply -f config-management.yaml
```

### Sync the root repository using Config Sync in the multi-repo mode

To sync the root repository using Config Sync in the multi-repo mode (CSMR), the cluster admin should follow these steps:

Step 1: create a file named `config-management.yaml` with a `ConfigManagement` custom resource (CR):

```yaml
# config-management.yaml
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  # Enable multi-repo mode to use new features
  enableMultiRepo: true
```

Step 2: apply the `ConfigManagement` CR:
```
kubectl apply -f config-management.yaml
```

Step 3: wait for the `RootSync` and `RepoSync` CRDs to be available:

```console
until kubectl get customresourcedefinitions rootsyncs.configsync.gke.io reposyncs.configsync.gke.io; \
do date; sleep 1; echo ""; done
```

Step 4: create a file named `rootsync.yaml` with a `RootSync` CR:
```
# root-sync.yaml
# If you are using a Config Sync version earlier than 1.7,
# use: apiVersion: configsync.gke.io/v1alpha1
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: hierarchy
  git:
    repo: https://github.com/GoogleCloudPlatform/anthos-config-management-samples/
    branch: init
    dir: hierarchical-format/config
    # We recommend securing your source repository.
    # Other supported auth: `ssh`, `cookiefile`, `token`, `gcenode`.
    auth: none
    # Refer to a Secret you create to hold the private key, cookiefile, or token.
    # secretRef:
    #   name: SECRET_NAME
```

Step 5: apply the `RootSync` CR:
```
kubectl apply -f rootsync.yaml
```


## Checking the sync status

You can check if Config Sync successfully syncs all configs to your cluster using the `nomos status` command.

```console
 nomos status
```

Example Output:
```console
*your-cluster
  --------------------
  <root>   https://github.com/GoogleCloudPlatform/anthos-config-management-samples/namespace-inheritance/config@init
  SYNCED   <commit-id>
```

## Examining your configs

The `config` directory includes ClusterRoles, ClusterRoleBindings, CRDs, Namespaces, RoleBindings, ServiceAccounts,
ResourceQuotas, NetworkPolicies, LimitRanges and CRs.
These configs are applied as soon as the Config Sync is configured to read from the repo.

All objects managed by Config Sync have the `app.kubernetes.io/managed-by` label set to `configmanagement.gke.io`.

- List namespaces managed by Config Sync
  ```console
  kubectl get ns -l app.kubernetes.io/managed-by=configmanagement.gke.io
  ```

  Example Output:
  ```console
  NAME        STATUS   AGE
  team-1      Active   28m
  team-2      Active   28m
  ```

- List CRDs managed by Config Sync
  ```console
  kubectl get crds -A -l app.kubernetes.io/managed-by=configmanagement.gke.io
  ```

  Example Output:
  ```console
  NAME                          CREATED AT
  crontabs.stable.example.com   2021-05-04T14:58:14Z
  ```

- List rolebindings managed by Config Sync
  ```console
  kubectl get rolebindings -A -l app.kubernetes.io/managed-by=configmanagement.gke.io
  ```

  Example Output:
  ```console
  NAMESPACE   NAME                            ROLE                        AGE
  team-1      secret-reader                   ClusterRole/secret-reader   29m
  team-2      secret-admin                    ClusterRole/secret-admin    29m
  ```