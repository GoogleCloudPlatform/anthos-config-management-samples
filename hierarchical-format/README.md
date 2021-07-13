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


## Configuring syncing from the repository

You can configure syncing from the Git repository using GCP console or gcloud.

### Using GCP Console

Following the console instructions for
[configuring Config Sync](https://cloud.google.com/anthos-config-management/docs/how-to/installing-config-sync#configuring-config-sync),
you need to

- Select **None** in the **Git Repository Authentication for ACM** section
- Select **Enable Config Sync** in the **ACM settings for your clusters** section
   - If you're using your forked repo, the **URL** should be the Git repository url for your fork: `https://github.com/<YOUR_ORGANIZATION>/anthos-config-management-samples.git`; otherwise the **URL** should be `https://github.com/GoogleCloudPlatform/anthos-config-management-samples.git`
   - the **Branch** should be `init`.
   - the **Tag/Commit** should be `HEAD`.
   - the **Source format** field should **hierarchy**.
   - the **Policy directory** field should be `hierarchical-format/config`.

### Using gcloud

You can also configure the Git repository information in a YAML file and use `gcloud` to apply the file.

1.  Create a file named `config-management.yaml` and copy the following YAML file into it:
    ```yaml
    # config-management.yaml
    
    apiVersion: configmanagement.gke.io/v1
    kind: ConfigManagement
    metadata:
     name: config-management
    spec:
     sourceFormat: hierarchy
     git:
       syncRepo: https://github.com/GoogleCloudPlatform/anthos-config-management-samples/
       syncBranch: init
       secretType: none
       policyDir: hierarchical-format/config
    ```
1.  Apply the config-management.yaml file:
    ```console
    gcloud alpha container hub config-management apply \
        --membership=CLUSTER_NAME \
        --config=CONFIG_YAML_PATH \
        --project=PROJECT_ID
    ```

   Replace the following:
   - `CLUSTER_NAME`: the name of the registered cluster that you want to apply this configuration to
   - `CONFIG_YAML_PATH`: the path to `config-management.yaml`
   - `PROJECT_ID`: your project ID

## Verifying the installation

### Using GCP Console
1. In the Cloud Console, go to the [Anthos Config Management](https://console.cloud.google.com/anthos/config_management) page.
1. View the **Status** column. A successful installation has a status of `Synced`.

### Using gcloud
Run the following command to get the status
```console
gcloud alpha container hub config-management status --project=PROJECT_ID
```
Replace `PROJECT_ID` with your project's ID.

A successful installation has a status of `SYNCED`.

### Using nomos
Run the following command to get the status
```console
nomos status
```

Example Output:
```console
*your-cluster
  --------------------
  <root>   https://github.com/GoogleCloudPlatform/anthos-config-management-samples/hierarchical-format/config@init   
  SYNCED   c4fee081 
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
