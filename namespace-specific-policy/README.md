# Configuring namespace specific policies

One cluster can be shared between multiple tenants. For multi-tenancy, the namespaces used by different tenants should have different policies according to the best practices for multi-tenancy. This doc walks you through the steps for configuring namespace specific policies, such as Role, RoleBinding and NetworkPolicy for a cluster shared between tenants.

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
This example contains three namespaces for different tenants. It contains the  following directories and files.
```
.
├── configsync
│   ├── tenant-a
│   │   ├── ~g_v1_namespace_default.yaml
│   │   ├── networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   │   ├── rbac.authorization.k8s.io_v1_rolebinding_tenant-admin-rolebinding.yaml
│   │   └── rbac.authorization.k8s.io_v1_role_tenant-admin.yaml
│   ├── tenant-b
│   │   ├── ~g_v1_namespace_default.yaml
│   │   ├── networking.k8s.io_v1_networkpolicy_deny-all.yaml
│   │   ├── rbac.authorization.k8s.io_v1_rolebinding_tenant-admin-rolebinding.yaml
│   │   └── rbac.authorization.k8s.io_v1_role_tenant-admin.yaml
│   └── tenant-c
│       ├── ~g_v1_namespace_default.yaml
│       ├── networking.k8s.io_v1_networkpolicy_deny-all.yaml
│       ├── rbac.authorization.k8s.io_v1_rolebinding_tenant-admin-rolebinding.yaml
│       └── rbac.authorization.k8s.io_v1_role_tenant-admin.yaml
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
├── README.md
└── scripts
    └── render.sh
```

The directory `configsync-src` contains the configuration in kustomize format. They are for one base and  three overlays `tenant-a`, `tenant-b` and `tenant-c`. Each overlay is a customization of the shared `base`. The difference between different overlays is from two parts:
- Namespace. The configuration inside the directory `configsync-src/<TENANT>` is all in the namespace `<TENANT>`. This is achieved by adding the namespace directive in `configsync-src/<TENANT>/kustomization.yaml`. For example, in `configsync-src/tenant-a/kustomization.yaml`:
Namespace: tenant-a

- RoleBinding. For each tenant, the RoleBinding is for a different Group. For example, in `configsync-src/tenant-a`, the RoleBinding is for the group `tenant-a-admin@mydomain.com`. This is achieved by applying the patch file `configsync-src/tenant-a/rolebinding.yaml`. So the RoleBinding from the `base` is overwritten.


### [optional] Update the namespace specific policies
If you need to update some configuration, you need to fork this example repository into your organization
and clone the forked repo locally.

```
$ git clone https://github.com/<YOUR_ORGANIZATION>/anthos-config-management-samples acm-samples
```

Then you can follow the instructions in this session. It is optional and shouldn’t affect the steps below.
#### Update the base
When you add new configuration or update configuration under the directory `acm-samples/namespace-specific-policy/configsync-src/base`, the change will be propagated to configuration for all of `tenant-a`, `tenant-b` and `tenant-c`.
#### Update an overlay
An overlay is a kustomization that depends on another customization.
In this example, there are three overlays: `tenant-a`, `tenant-b`
and `tenant-c`. If you only need to update some configuration in
one overlay, you only need to touch the directory for that overlay.

Here is an example of adding another Role in the overlay `tenant-a`.
We can add a new file
`acm-samples/namespace-specific-policy/configsync-src/tenant-a/another-role.yaml`
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
`acm-samples/namespace-specific-policy/configsync-src/tenant-a/kustomization.yaml`
by adding the file name under `resources`.

```yaml
# kustomization.yaml
resources:
- ../base
- another-role.yaml
...
```

After the update, you should rebuild the kustomize output for each namespace by revoking the `render.sh` script.
```
$ cd acm-samples/namespace-specific-policy
$ ./scripts/render.sh
```

Then you can commit and push the update.

```
$ git add .
$ git commit -m 'update configuration'
$ git push
```

Note that in this example, the kustomize output is written into a different
directory on the same branch in the same Git repository. You can also write
the kustomize output into a different Git repository if desired.

## Sync namespace specific policies

Now you can configure ConfigSync to sync these policies to the cluster.
You can do this either using the GCP console or `gcloud`.

### Using GCP console

Following the console instructions for
[configuring Config Sync](https://cloud.google.com/anthos-config-management/docs/how-to/installing-config-sync),
you need to

- Select **None** in the **Git Repository Authentication for ACM** section
- Select **Enable Config Sync** in the **ACM settings for your clusters** section
   - If you're using your forked repo, the **URL** should be the Git repository url for your fork: `https://github.com/<YOUR_ORGANIZATION>/anthos-config-management-samples.git`; otherwise the **URL** should be `https://github.com/GoogleCloudPlatform/anthos-config-management-samples.git`
   - the **Branch** should be `init`.
   - the **Tag/Commit** should be `HEAD`.
   - the **Source format** field should **unstructured**.
   - the **Policy directory** field should be `namespace-specific-policy/configsync`.

### Using gcloud

You can also configure the Git repository information in a
`config-management.yaml` file and use a `gcloud` command to apply it.

1. Create the `config-management.yaml` file

   ```
   cat << EOF > config-management.yaml
   apiVersion: configmanagement.gke.io/v1
   kind: ConfigManagement
   metadata:
     name: config-management
   spec:
     git:
       policyDir: namespace-specific-policy/configsync
       secretType: none
       syncBranch: init
       # If you're using your forked repo,
       # syncRepo field should be https://github.com/<YOUR_ORGANIZATION>/anthos-config-management-samples.git
       syncRepo: https://github.com/GoogleCloudPlatform/anthos-config-management-samples.git
     sourceFormat: unstructured
   EOF
   ```

1. Apply the `config-management.yaml` file.

   ```
   gcloud alpha container hub config-management apply \
   --membership=CLUSTER_NAME \
   --config=config-management.yaml \
   --project=PROJECT_ID
   ```

   Replace the following variables:
   - `CLUSTER_NAME`: the name of the registered cluster that you want to apply
     this configuration to.
   - `PROJECT_ID`: your GCP project ID.

## Verify namespace specific policies are synced
Now you can verify that the namespace specific policies are synced to the cluster.

```
nomos status
```

You can also double-check the resources exist in the cluster.

```
# Verify the RoleBinding exist
$ kubectl get RoleBinding/tenant-admin-rolebinding -n tenant-a

# Verify the Role exist
$ kubectl get Role/tenant-admin -n tenant-a

# Verify the NetworkPolicy exist
$ kubectl get NetworkPolicy/deny-all -n tenant-a
```


## Cleanup
To clean up the tenant namespaces and policies for them, we recommend removing the directories that contain their configuration from your Git repository.

```
$ rm -r acm-samples/namespace-specific-policy/configsync/tenant-*/*
$ git add .
$ git commit -m 'clean up'
$ git push
```

When the last commit from the root repository is synced, the three namespace `tenant-a`, `tenant-b` and `tenant-c` are deleted from the cluster.

To stop the syncing using ConfigSync, you can delete the ConfigManagement
resource.

```
kubectl delete -f config-management.yaml
```
