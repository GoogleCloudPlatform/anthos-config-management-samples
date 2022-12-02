# Config Sync Namespace Inheritance Example

This example demonstrates how to use 
[namespace inheritance](https://cloud.google.com/anthos-config-management/docs/concepts/namespace-inheritance)
with the [hierarchical format](https://cloud.google.com/anthos-config-management/docs/concepts/hierarchical-repo)
in [Config Sync](https://cloud.google.com/anthos-config-management/docs/config-sync-overview).

It contains three simple use cases:
* Inherited default NetworkPolicies can be customized by adding a second object in an individual namespace.
* Default RoleBindings can be inherited across multiple namespaces in cases ClusterRoleBindings are too broad.
* Default ResourceQuota can be overridden using NamespaceSelectors.

## Before you begin

- You’ll need a cluster that has Config Sync installed.
  Please follow the [instructions](https://cloud.google.com/anthos-config-management/docs/how-to/installing-config-sync)
  to install Config Sync if it is not set up yet.
- [Install the `nomos` command](https://cloud.google.com/anthos-config-management/docs/how-to/nomos-command#installing)

## Viewing the compiled configs in the repo

You can use the `nomos hydrate` command to view the combined contents of your repo on each enrolled cluster.
This example stores the output from `nomos hydrate` in a `compiled/` directory to illustrate what hierarchical mode
actually does under the covers.

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
   - the **Policy directory** field should be `namespace-inheritance/config`.

### Using gcloud

You can also configure the Git repository information in a config-management.yaml file and use a gcloud command to apply the file.

1.  Create a file named config-management.yaml and copy the following YAML file into it:
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
       policyDir: namespace-inheritance/config
    ```
1.  Apply the config-management.yaml file:
    ```console
    gcloud beta container fleet config-management apply \
        --membership=CLUSTER_NAME \
        --config=CONFIG_YAML_PATH \
        --project=PROJECT_ID
    ```

   Replace the following:
   - CLUSTER_NAME: the name of the registered cluster that you want to apply this configuration to
   - CONFIG_YAML_PATH: the path to your config-management.yaml file
   - PROJECT_ID: your project ID

## Verifying the installation

### Using GCP Console
1. In the Cloud Console, go to the [Anthos Config Management](https://console.cloud.google.com/anthos/config_management) page.
1. View the **Status** column. A successful installation has a status of `Synced`.

### Using gcloud
Run the following command to get the status
```console
gcloud beta container fleet config-management status --project=PROJECT_ID
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
  <root>   https://github.com/GoogleCloudPlatform/anthos-config-management-samples/namespace-inheritance/config@init   
  SYNCED   c4fee081 
```

## Examining your configs

The `config` directory includes ClusterRoles, ClusterRoleBindings, Namespaces, Roles, RoleBindings, NetworkPolicies,
ResourceQuotas, and NamespaceSelectors.
These configs are applied as soon as the Config Sync is configured to read from the repo.

All objects managed by Config Sync have the `app.kubernetes.io/managed-by` label set to `configmanagement.gke.io`.

- List namespaces managed by Config Sync
  ```console
  kubectl get ns -l app.kubernetes.io/managed-by=configmanagement.gke.io
  ```

  Example Output:
  ```console
  NAME          STATUS   AGE
  analytics     Active   7h10m
  gamestore     Active   7h10m
  incubator-1   Active   7h10m
  incubator-2   Active   7h10m
  ```

- List roles managed by Config Sync
  ```console
  kubectl get roles -A -l app.kubernetes.io/managed-by=configmanagement.gke.io
  ```
  
  Example Output:
  ```console
  NAMESPACE     NAME                CREATED AT
  analytics     eng-viewer          2021-04-28T19:10:43Z
  gamestore     eng-viewer          2021-04-28T19:10:43Z
  incubator-1   incubator-1-admin   2021-04-28T19:18:17Z
  ```
  
  Explanation:
  - The `eng-viewer` roleb is created in namespaces under the `eng`
    [abstract namespace directory](https://cloud.google.com/anthos-config-management/docs/how-to/namespace-scoped-objects#abstract-namespace-config)
    because it is inherited from `config/namespaces/eng/eng-role.yaml`.
  - The `incubator-1-admin` role is created in the `incubator-1` namespace
    because of the config `config/namespaces/rnd/incubator-1/incubator-1-admin-role.yaml`.

- List rolebindings managed by Config Sync
  ```console
  kubectl get rolebindings -A -l app.kubernetes.io/managed-by=configmanagement.gke.io
  ```
  
  Example Output:
  ```console
  NAMESPACE     NAME               ROLE                    AGE
  analytics     eng-admin          Role/eng-viewer         10m
  analytics     viewers            ClusterRole/view        18h
  gamestore     bob-rolebinding    ClusterRole/foo-admin   18h
  gamestore     eng-admin          Role/eng-viewer         10m
  gamestore     viewers            ClusterRole/view        18h
  incubator-1   viewers            ClusterRole/view        19h
  incubator-2   viewers            ClusterRole/view        19h
  ```
  
  Explanation:
  - The `viewers` rolebinding is created in all managed namespaces because it is inherited from
    `config/namespaces/viewers-rolebinding.yaml`.
  - The `eng-admin` rolebinding is created in namespaces under the `eng`
    [abstract namespace directory](https://cloud.google.com/anthos-config-management/docs/how-to/namespace-scoped-objects#abstract-namespace-config)
    because it is inherited from `config/namespaces/eng/eng-rolebinding.yaml`.
  - `bob-rolebinding` is created in the `gamestore` namespace
    because of the config `config/namespaces/eng/gamestore/bob-rolebinding.yaml`.

- List networkpolicies managed by Config Sync
  ```console
  kubectl get networkpolicies.networking.k8s.io -A -l app.kubernetes.io/managed-by=configmanagement.gke.io
  ```
  
  Example Output:
  ```console
  NAMESPACE     NAME                       POD-SELECTOR    AGE
  analytics     allow-gamestore-ingress    app=gamestore   7h17m
  analytics     default-deny-all-traffic   <none>          7h17m
  gamestore     allow-gamestore-ingress    app=gamestore   7h17m
  gamestore     default-deny-all-traffic   <none>          7h17m
  incubator-1   default-deny-all-traffic   <none>          7h17m
  incubator-2   default-deny-all-traffic   <none>          7h17m
  ```
  
  Explanation:
  - The `default-deny-all-traffic` networkpolicy is created in all managed namespaces because it is inherited from
    `config/namespaces/network-policy-default-deny-all.yaml`.
  - The `allow-gamestore-ingress` networkpolicy is created in namespaces under the `eng`
    [abstract namespace directory](https://cloud.google.com/anthos-config-management/docs/how-to/namespace-scoped-objects#abstract-namespace-config)
    because it is inherited from `config/namespaces/eng/network-policy-allow-gamestore-ingress.yaml`.
    Ingress traffic will be allowed only to Pods in the `gamestore` namespace with the `app:gamestore` label.
  
- List resourcequotas managed by Config Sync
  ```console
  kubectl get resourcequotas -A -l app.kubernetes.io/managed-by=configmanagement.gke.io
  ```
  
  Example Output:
  ```console
  NAMESPACE   NAME    AGE     REQUEST                                   LIMIT
  analytics   quota   7h19m   cpu: 0/100m, memory: 0/100Mi, pods: 0/1   
  gamestore   quota   7h19m   cpu: 0/200m, memory: 0/200Mi, pods: 0/1  
  ```

  Explanation:
  - The `quota` resourcequota is created in the `analytics` namespace because the `analytics-selector` limits which
    namespaces can inherit that config.
  - The `quota` resourcequota is created in the `gamestore` namespace because the `gamestore-selector` limits which
    namespaces can inherit that config.
