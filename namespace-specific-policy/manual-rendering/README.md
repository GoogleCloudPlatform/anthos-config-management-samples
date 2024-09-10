# Configuring namespace specific policies

One cluster can be shared between multiple teams. For multi-tenancy, the namespaces used by different teams should have different policies according to the best practices for multi-tenancy. This doc walks you through the steps for configuring namespace specific policies, such as Role, RoleBinding and NetworkPolicy for a cluster shared between teams.

## Objectives
In this tutorial, you will
- Learn how to use Kustomize to get namespace specific policies from a common base.
- Learn how to sync policies in your Git repository to a cluster.

## Before you begin
This section describes prerequisites you must meet before this tutorial.
- ConfigSync is installed on your cluster, with the version at least 1.7.0. If not, you can install
  it following the [instructions](https://cloud.google.com/anthos-config-management/docs/how-to/installing-config-sync).
- `git` is installed in your local machine.
- `kustomize` is installed in your local machine. If not, you can install it by `gcloud components install kustomize`.

## Create namespace specific policies

### Get the example configuration
This `manual-rendering` example contains four namespaces for different teams. It contains the following directories and files.
```
.
├── configsync
│   ├── external-team_networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   ├── external-team_rbac.authorization.k8s.io_v1_role_team-admin.yaml
│   ├── external-team_rbac.authorization.k8s.io_v1_rolebinding_team-admin-rolebinding.yaml
│   ├── my-namespace_v1_configmap_my-configmap-5f4h4hkd89.yaml
│   ├── team-a_networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   ├── team-a_rbac.authorization.k8s.io_v1_role_team-admin.yaml
│   ├── team-a_rbac.authorization.k8s.io_v1_rolebinding_team-admin-rolebinding.yaml
│   ├── team-b_networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   ├── team-b_rbac.authorization.k8s.io_v1_role_team-admin.yaml
│   ├── team-b_rbac.authorization.k8s.io_v1_rolebinding_team-admin-rolebinding.yaml
│   ├── team-c_networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   ├── team-c_rbac.authorization.k8s.io_v1_role_team-admin.yaml
│   ├── team-c_rbac.authorization.k8s.io_v1_rolebinding_team-admin-rolebinding.yaml
│   ├── v1_namespace_external-team.yaml
│   ├── v1_namespace_team-a.yaml
│   ├── v1_namespace_team-b.yaml
│   └── v1_namespace_team-c.yaml
├── README.md
└── scripts
    └── render.sh
```


### [optional] Update the namespace specific policies
If you need to update some configuration, you need to fork this example repository into your organization
and clone the forked repo locally.

```console
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

After the update, you should rebuild the kustomize output for each namespace by revoking the `render.sh` script.
```console
$ cd acm-samples/namespace-specific-policy/manual-rendering
$ ./scripts/render.sh
```

Then you can commit and push the update.

```console
$ git add .
$ git commit -m 'update configuration'
$ git push
```

Note that in this example, the kustomize output is written into a different
directory on the same branch in the same Git repository. You can also write
the kustomize output into a different Git repository if desired.

## Sync namespace specific policies

Now you can configure ConfigSync to sync these policies to the cluster.
You can do this using the GCP console.

### Using GCP console

Follow the console instructions for
[configuring Config Sync](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync#console).

## Verify namespace specific policies are synced
Now you can verify that the namespace specific policies are synced to the cluster.

```
nomos status
```

You can also double-check the resources exist in the cluster.

```bash
# Verify that the RoleBinding exists
$ kubectl get RoleBinding/team-admin-rolebinding -n team-a

# Verify that the Role exists
$ kubectl get Role/team-admin -n team-a

# Verify that the NetworkPolicy exists
$ kubectl get NetworkPolicy/deny-all -n team-a
```


## Cleanup
To clean up the team namespaces and policies for them, we recommend removing the directories that contain their configuration from your Git repository.

```bash
$ rm -r acm-samples/namespace-specific-policy/manual-rendering/configsync/team-*/*
$ git add .
$ git commit -m 'clean up commit 1'
$ git push

# Run once Config Sync syncs the changes in commit 1
$ rm -r acm-samples/namespace-specific-policy/manual-rendering/configsync/*
$ git add .
$ git commit -m 'clean up commit 2'
$ git push
```

Two separate commits are necessary as Config Sync doesn't allow the removal of all namespaces or cluster-scoped resources in a single commit.

When the last commit from the root repository is synced, the four namespaces `team-a`, `team-b`, `team-c` and `external-team` are deleted from the cluster.

To stop the syncing using ConfigSync, follow the instructions [here](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/stopping-resuming-syncing).