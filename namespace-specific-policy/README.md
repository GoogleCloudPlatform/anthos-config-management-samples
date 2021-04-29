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
├── config
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
├── deploy
│   ├── tenant-a
│   │   └── manifest.yaml
│   ├── tenant-b
│   │   └── manifest.yaml
│   └── tenant-c
│       └── manifest.yaml
├── README.md
└── scripts
    └── render.sh
```

The directory `config` contains the configuration in kustomize format. They are for one base and  three overlays `tenant-a`, `tenant-b` and `tenant-c`. Each overlay is a customization of the shared `base`. The difference between different overlays is from two parts:
- Namespace. The configuration inside the directory `config/<TENANT>` is all in the namespace `<TENANT>`. This is achieved by adding the namespace directive in `config/<TENANT>/kustomization.yaml`. For example, in `config/tenant-a/kustomization.yaml`:
Namespace: tenant-a

- RoleBinding. For each tenant, the RoleBinding is for a different Group. For example, in `config/tenant-a`, the RoleBinding is for the group `tenant-a-admin@mydomain.com`. This is achieved by applying the patch file `config/tenant-a/rolebinding.yaml`. So the RoleBinding from the `base` is overwritten.

Fork the example repository into your organization and clone the forked repo locally.

```
$ git clone https://github.com/<YOUR_ORGANIZATION>/anthos-config-management-samples acm-samples
```

After this, the example configuration is under your local directory `acm-samples/namespace-specific-policy`.

### [optional] Update the namespace specific policies
If you need to update some configuration, you can follow the instructions in this session. It is optional and shouldn’t affect the steps below.
#### Update the base
When you add new configuration or update configuration under the directory `acm-samples/namespace-specific-policy/config/base`, the change will be propagated to configuration for all of `tenant-a`, `tenant-b` and `tenant-c`.
#### Update an overlay
An overlay is a kustomization that depends on another customization. In this example, there are three overlays: `tenant-a`, `tenant-b` and `tenant-c`. If you only need to update some configuration in one overlay, for example, add another Role to  `tenant-a`. Then you only need to touch the directory `acm-samples/namespace-specific-policy/config/tenant-a`.


After the update, you should rebuild the kustomize output for each namespace by revoking the `render.sh` script.
```
$ cd acm-samples/namespace-specific-policy
$ ./scripts/render.sh
```

Then you can commit and push the update.

```
$ git add .
$ git commit -m 'update configuration'
$ git push origin main
```

Note that in this example, the kustomize output is written into a different
directory on the same branch in the same Git repository. You can also write
the kustomize output into a different Git repository if desired.

## Sync namespace specific policies

Now you can configure ConfigSync to sync these policies to the cluster.

Following the console instructions for
[configuring Config Sync](https://cloud.google.com/anthos-config-management/docs/how-to/installing-config-sync),
you need to

- Select **None** in the **Git Repository Authentication for ACM** section
- Select **Enable Config Sync** in the **ACM settings for your clusters** section
   - the **URL** should be the Git repository url for your fork: `https://github.com/<YOUR_ORGANIZATION>/anthos-config-management-samples.git`.
   - the **Branch** should be `main`.
   - the **Tag/Commit** should be `HEAD`.
   - the **Source format** field should **unstructured**.
   - the **Policy directory** field should be `namespace-specific-configuration/deploy`.


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
$ rm -r acm-samples/namespace-specific-policy/deploy/tenant-a acm-samples/namespace-specific-policy/deploy/tenant-b acm-samples/namespace-specific-policy/deploy/tenant-c
$ git add .
$ git commit -m 'clean up'
$ git push
```

When the last commit from the root repository is synced, the three namespace `tenant-a`, `tenant-b` and `tenant-c` are deleted from the cluster.


