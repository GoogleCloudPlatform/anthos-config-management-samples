# Config Sync Namespace Inheritance Example

This example demonstrates how to use 
[namespace inheritance](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/concepts/namespace-inheritance)
with the [hierarchical format](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/concepts/hierarchical-repo)
in [Config Sync](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/overview).

It contains three simple use cases:
* Inherited default NetworkPolicies can be customized by adding a second object in an individual namespace.
* Default RoleBindings can be inherited across multiple namespaces in cases ClusterRoleBindings are too broad.
* Default ResourceQuota can be overridden using NamespaceSelectors.

## Before you begin

- You’ll need a cluster that has Config Sync installed.
  Please follow the [instructions](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/installing)
  to install Config Sync if it is not set up yet.
- [Install the `nomos` command](https://cloud.devsite.corp.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/nomos-command#installing)

## Viewing the compiled configs in the repo

You can use the `nomos hydrate` command to view the combined contents of your repo on each enrolled cluster.
This example stores the output from `nomos hydrate` in a `compiled/` directory to illustrate what hierarchical mode
actually does under the covers.

## Configuring syncing from the repository

First, create a file with a `ConfigManagement` custom resource:

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

Apply it to the cluster:

```console
kubectl apply -f config-management.yaml
```

Wait for the `RootSync` and `RepoSync` CRDs to be available:

```console
until kubectl get customresourcedefinitions rootsyncs.configsync.gke.io reposyncs.configsync.gke.io; \
do date; sleep 1; echo ""; done
```

Then create a file with a `RootSync` custom resource:

```yaml
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
    # If you fork this repo, change the url to point to your fork
    repo: https://github.com/GoogleCloudPlatform/anthos-config-management-samples/
    # If you move the configs to a different branch, update the branch here
    branch: init
    dir: namespace-inheritance/config
    # We recommend securing your source repository.
    # Other supported auth: `ssh`, `cookiefile`, `token`, `gcenode`.
    auth: none
    # Refer to a Secret you create to hold the private key, cookiefile, or token.
    # secretRef:
    #   name: SECRET_NAME
```

Then, apply it to the cluster:

```console
kubectl apply -f root-sync.yaml
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

- List rolebindings managed by Config Sync
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
    [abstract namespace directory](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/namespace-scoped-objects#abstract-namespace-config)
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
  analytics     mike-rolebinding   ClusterRole/foo-admin   18h
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
    [abstract namespace directory](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/namespace-scoped-objects#abstract-namespace-config)
    because it is inherited from `config/namespaces/eng/eng-rolebinding.yaml`.
  - `mike-rolebinding` is created in the `analytics` namespace
    because of the config `config/namespaces/eng/analytics/mike-rolebinding.yaml`.
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
    [abstract namespace directory](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/namespace-scoped-objects#abstract-namespace-config)
    because it is inherited from `config/namespaces/eng/network-policy-allow-gamestore-ingress.yaml`.
    Ingress traffic will be allowed only to Pods in the `gamestore` namespace with the `app:gamestore` label.
  
- List resourcequotas managed by Config Sync
  ```console
  kubectl get resourcequotas -A -l app.kubernetes.io/managed-by=configmanagement.gke.io
  ```
  
  Example Output:
  ```console
  NAMESPACE   NAME        AGE     REQUEST                    LIMIT
  analytics   pod-quota   7h19m   pods: 0/1, secrets: 1/5    
  gamestore   pod-quota   7h19m   pods: 0/5, secrets: 1/10  
  ```

  Explanation:
  - The `pod-quota` resourcequota is created in the `analytics` namespace because the `analytics-selector` limits which
    namespaces can inherit that config.
  - The `pod-quota` resourcequota is created in the `gamestore` namespace because the `gamestore-selector` limits which
    namespaces can inherit that config.
