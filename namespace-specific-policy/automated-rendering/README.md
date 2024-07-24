# Configuring namespace specific policies

One cluster can be shared between multiple teams. For multi-tenancy, the namespaces used by different teams should have different policies according to the best practices for multi-tenancy. This doc walks you through the steps for configuring namespace specific policies, such as Role, RoleBinding and NetworkPolicy for a cluster shared between teams.

## Objectives
In this tutorial, you will
- Configure your repository with Kustomize configurations to get namespace specific policies from a common base.
- Preview and validate the configs that you create.
- Use Config Sync to automatically render and sync your cluster to your repository.
- Verify that your installation succeeded.

## Before you begin
This section describes prerequisites you must meet before this tutorial.
- ConfigSync is installed on your cluster, with the version at least 1.9.0. If not, you can install
  it following the [instructions](https://cloud.google.com/anthos-config-management/docs/how-to/installing-config-sync).
- Install the `nomos` command. If you've already installed `nomos`, make sure you upgrade it to version 1.9.0 or later.

## Create namespace specific policies

### Get the example configuration

The `automated-rendering` directory includes a root `kustomization.yaml` file that references the `example` kustomization directory.

```yaml
resources:
- configsync-src/example
```

The `automated-rendering/configsync-src` file is a symbolic link that links to the source directory: `../configsync-src`.


### [optional] Update the namespace specific policies
If you need to update some configuration, you need to fork this example repository into your organization
and clone the forked repo locally.

```
$ git clone https://github.com/<YOUR_ORGANIZATION>/anthos-config-management-samples acm-samples
```

Then you can follow the instructions in this session. It is optional and shouldn’t affect the steps below.
#### Update the base
When you add new configuration or update configuration under the directory `acm-samples/namespace-specific-policy/configsync-src/example/base`, the change will be propagated to configuration for all of `team-a`, `team-b` and `team-c`.
#### Update an overlay
An overlay is a kustomization that depends on another kustomization.
In this example, there are three overlays: `team-a`, `team-b`
and `team-c`. If you only need to update some configuration in
one overlay, you only need to touch the directory for that overlay.

Here is an example of adding another Role in the overlay `team-a`.
We can add a new file
`acm-samples/namespace-specific-policy/configsync-src/example/team-a/another-role.yaml`
with the following content:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```
Then include the new config in
`acm-samples/namespace-specific-policy/configsync-src/example/team-a/kustomization.yaml`
by adding the file name under `resources`.

```yaml
# kustomization.yaml
resources:
- ../base
- another-role.yaml
...
```

Then you can commit and push the update.

```
$ git add .
$ git commit -m 'update configuration'
$ git push
```

## Preview and validate rendered configs

Before Config Sync renders the configs and syncs them to the cluster, ensure that the configs
are accurate by running `nomos hydrate` to preview the rendered configuration and running `nomos vet`
to validate that the format is correct.

1. Run the following `nomos hydrate` with the following flags:

```console
nomos hydrate --source-format=unstructured --output=OUTPUT_DIRECTORY
```

In this command:

- `--source-format=unstructured` lets `nomos hydrate` work on an unstructured repository.
  Since you are using Kustomize configurations, you need to use an unstructured repository and add this flag.
- `--output=OUTPUT_DIRECTORY` lets you define a path to the rendered configs.
  Replace OUTPUT_DIRECTORY with the location that you want the output to be saved in.

1. Check the syntax and validity of your configs by running `nomos vet` with the following flags:

```console
nomos vet \
--source-format=unstructured \
--keep-output=true \
--output=OUTPUT_DIRECTORY
```
In this command:

- `--source-format=unstructured` lets `nomos vet` work on an unstructured repository.
- `--keep-output=true` saves the rendered configs.
- `--output=OUTPUT_DIRECTORY` is the path to the rendered configs.

## Sync namespace specific policies

Now you can configure ConfigSync to sync these policies to the cluster.
You can do this either using the GCP console or `gcloud`.

### Using GCP console

Follow the console instructions for
[configuring Config Sync](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync#console).

### Using gcloud

You can also configure the Git repository information using `gcloud` as described [here](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync#gcloud).


## Verify namespace specific policies are synced
Now you can verify that the namespace specific policies are synced to the cluster.

```
nomos status
```

You can also double-check the resources exist in the cluster.

```
# Verify the RoleBinding exist
$ kubectl get RoleBinding/team-admin-rolebinding -n team-a

# Verify the Role exist
$ kubectl get Role/team-admin -n team-a

# Verify the NetworkPolicy exist
$ kubectl get NetworkPolicy/deny-all -n team-a
```


## Cleanup
To clean up the team namespaces and policies for them, we recommend removing the directories that contain their configuration from your Git repository.

```bash
$ rm -r acm-samples/namespace-specific-policy/automated-rendering/configsync/example/*
$ git add .
$ git commit -m 'clean up commit 1'
$ git push

# Run once Config Sync syncs the changes in commit 1
$ rm -r acm-samples/namespace-specific-policy/automated-rendering/configsync/*
$ git add .
$ git commit -m 'clean up commit 2'
$ git push
```

Two separate commits are necessary as Config Sync doesn't allow the removal of all namespaces or cluster-scoped resources in a single commit.

When the last commit from the root repository is synced, the four namespaces `team-a`, `team-b`, `team-c` and `external-team` are deleted from the cluster.

To stop the syncing using ConfigSync, follow the instructions [here](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/stopping-resuming-syncing).