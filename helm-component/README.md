# cert-manager-example

We use an off-the-shelf component [cert-manager](https://github.com/jetstack/cert-manager) as an example to demonstrate
how [Config Sync](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync) syncs an unstructured repo to your cluster using Helm template.

To sync the Helm chart to your cluster, you can run `helm template` and commit the rendered manifest to your repo. 

## Objectives
- Configure Config Sync to install a Helm component
- Demonstrate how to use helm template to render manifests
- Demonstrate usage of [unstructured repos](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/unstructured-repo)

## Before you begin
- You’ll need a cluster that has Config Sync installed.
  Please follow the [instructions](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/installing)
  to install Config Sync if it is not set up yet.
- Install [Helm](https://helm.sh/) to render the manifests.

## Preparing the Git repository

### Set up a git repository
You can fork the repository to your local workstation, or create a new one with the following steps:
- [Create a new repository](https://docs.github.com/en/github/getting-started-with-github/create-a-repo)
- Create a directory that contains the configuration that you want to sync to and add a README.md file in the directory.
  ```shell script
  mkdir manifests && touch manifests/README.md
  ```
- Create a namespace where you want to install the component.
  ```yaml
  # manifests/namespace-cert-manager.yaml
  apiVersion: v1
  kind: Namespace
  metadata:
   name: cert-manager
  ```
 
### Render the manifests using helm template.
There are two options to render the manifests.
You can download the helm chart locally and render the manifests upon your local chart.
Or you can directly render the remote chart.
- Download and render from local:
  ```shell script
  # Download the chart and unpack it in the local directory.
  helm pull jetstack/cert-manager --version 1.3.0 --untar

  # Render the template and write the rendered manifests into an output directory.
  helm template my-cert-manager cert-manager --namespace cert-manager --output-dir manifests
  ```
- Render from the remote chart:
  ```shell script
  # Render the template from a remote chart and write the rendered manifests into an output directory.
  helm template my-cert-manager jetstack/cert-manager --version 1.3.0 --namespace cert-manager --output-dir manifests
  ```
  
### Commit the changes to the repository:
   ```shell script
   git add .
   git commit -m 'Set up cert-manager manifests.'
   git push
   ```
   
## Configuring syncing from the Git repository
To configure syncing from the Git repository, your need to configure the git specification in your ConfigManagement
object, or your RootSync object.

If you are using the legacy git fields (spec.enableLegacyFields is set to true), update your ConfigManagement object:
```yaml
# config-management.yaml

apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
 name: config-management
spec:
 # clusterName is required and must be unique among all managed clusters
 clusterName: my-cluster
 enableMultiRepo: true
 enableLegacyFields: true
 git:
   syncRepo: https://github.com/GoogleCloudPlatform/anthos-config-management-samples/
   syncBranch: init
   secretType: none
   policyDir: helm-component/manifests
 sourceFormat: unstructured
```

If you are not using the legacy git fields, update your RootSync object:
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
 git:
   auth: none
   branch: init
   dir: helm-component/manifests
   repo: https://github.com/GoogleCloudPlatform/anthos-config-management-samples/
 sourceFormat: unstructured
```

## Verifying the installation
You can check the RootSync object status and the installed resources to check if the component is synced successfully.
```shell script
kubectl get rootsyncs -n config-management-system root-sync -o yaml
kubectl get all -n cert-manager
```

## Uninstalling the component
In order to help prevent accidental deletion, Config Sync does not allow you to remove all namespaces or
cluster-scoped resources in a single commit.
Follow the instructions to gracefully uninstall the component and remove the namespace in separate commits.
- Remove the cert-manager component.
  ```shell script
  git rm -rf manifests/cert-manager && git commit -m "uninstall cert-manager" && git push origin init
  ````
- Delete the cert-manager namespace.
  ```shell script
  git rm manifests/namespace-cert-manager.yaml && git commit -m "remove the cert-manager namespace" && git push origin init
  ````
- Verify the namespace does not exist.
  ```shell script
  Kubectl get namespace cert-namespace
  ```
