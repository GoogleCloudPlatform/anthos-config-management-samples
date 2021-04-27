# Config Sync Quickstarts

## Prerequisite 

Either install 1.7.0 release of [Anthos Config Management](https://cloud.google.com/anthos-config-management/docs/how-to/installing) and [Config Sync Operator](https://cloud.google.com/anthos-config-management/docs/how-to/installing-config-sync), or install [standalone Config Sync Operator](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/installing).

## Multi-Repo mode, unstructured format

For [Config Sync multi-repo mode](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/multi-repo) with unstructured format, use this [example](multirepo/).
The example contains `ClusterRole`, `CustomResourceDefinition`, configurations for Prometheus Operator for monitoring, `Rolebinding`, `Namespace`, and `RepoSync`.

First, create a files with a `ConfigManagement` custom resource:

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

Then create a files with a `RootSync` custom resource:

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
  sourceFormat: unstructured
  git:
    # If you fork this repo, change the url to point to your fork
    repo: https://github.com/GoogleCloudPlatform/anthos-config-management-samples/
    # If you move the configs to a different branch, update the branch here
    branch: init
    dir: "quickstart/multirepo/root"
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

### Root configs

You can verify resources in the "multirepo/root" directory has been synced to the cluster using `kubectl` and [`nomos`](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/nomos-command) commands:

```console
# Wait until source commit matches sync commit
kubectl get -f root-sync.yaml -w
# Check Config Sync status
nomos status
kubectl describe -f root-sync.yaml
kubectl get resourcegroups -n config-management-system
kubectl get <resources specified in the "multirepo/root" directory>
```

You may see transient `connection refused` error from admission webhook before it's ready. This error should disappear after a while.

```
KNV2009: Internal error occurred: failed calling webhook "v1.admission-webhook.configsync.gke.io": Post "https://admission-webhook.config-management-system.svc:8676/admission-webhook?timeout=3s": dial tcp 10.92.2.14:8676: connect: connection refused
```

### Namespace configs

The configs in the "multirepo/root" directory contains a `gamestore` namespace and a [`RepoSync` resource](multirepo/root/reposync-gamestore.yaml) in the `gamestore` namespace, referencing the "gamestore" directory in this git repository.

If you fork this example, you need to update the [`RepoSnc` resource](multirepo/root/reposync-gamestore.yaml)
to reference the right repository URL and git branch.

To verify resources in the "gamestore" directory has been synced to the cluster:

```console
# Wait until source commit matches sync commit
kubectl get reposync.configsync.gke.io/repo-sync -n gamestore -w
# Check Config Sync status
nomos status
kubectl describe reposync.configsync.gke.io/repo-sync -n gamestore
kubectl get resourcegroups -n gamestore
kubectl get <resources specified in the "gamestore" directory>
```

### Conflict changes

Try to change the value of [configmap/store-inventory](multirepo/namespaces/gamestore/configmap-inventory.yaml) annotation `marketplace.com/comments` in the cluster:

```console
kubectl edit configmaps store-inventory -n gamestore
```

The request should be rejected by the admission webhook.

### Valid changes

Try to change the same annotation in your git repository, the change can be synced to the cluster.

Note that you need to update [`RepoSync` resource](multirepo/root/reposync-gamestore.yaml) in your git repository to point to your own fork if you want to make changes in git.

## Mono-Repo mode, unstructured format

For Config Sync mono-repo mode with unstructured format, use this [example](monorepo/root).
The example contains `ClusterRole`, `CustomResourceDefinition`, and configurations for Prometheus Operator for monitoring.

First, create a file with a `ConfigManagement` custom resource:

```yaml
# config-management.yaml
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  git:
    # If you fork this repo, change the url to point to your fork
    syncRepo: https://github.com/GoogleCloudPlatform/anthos-config-management-samples/
    # If you move the configs to a different branch, update the branch here
    syncBranch: init
    # We recommend securing your source repository.
    # Other supported secretType: `ssh`, `cookiefile`, `token`, `gcenode`.
    secretType: none
    policyDir: quickstart/monorepo/root
  sourceFormat: unstructured
```

Then, apply it to the cluster:

```console
kubectl apply -f config-management.yaml
```

### Root configs

You can verify resources in the "monorepo/root" directory has been synced to the cluster using `kubectl` and [`nomos`](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/nomos-command) commands:

```console
# Check Config Sync status
nomos status
kubectl get <resources specified in the "monorepo/root" directory>
```
