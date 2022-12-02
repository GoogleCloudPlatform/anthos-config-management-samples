# cert-manager-example

We use an off-the-shelf component [cert-manager](https://github.com/jetstack/cert-manager) as an example to demonstrate
how [Config Sync](https://cloud.google.com/anthos-config-management/docs/config-sync-overview) syncs an unstructured repo to your cluster using Helm template.

To sync the Helm chart to your cluster, you can run `helm template` and commit the rendered manifest to your repo. 

## Objectives
- Learn how to use Config Sync to install an off-the-shelf Helm component
- Learn how to use helm template to render manifests
- Demonstrate usage of [unstructured repos](https://cloud.google.com/anthos-config-management/docs/how-to/unstructured-repo)

## Before you begin
- You’ll need a cluster that has Config Sync installed.
  Please follow the [instructions](https://cloud.google.com/anthos-config-management/docs/how-to/installing-config-sync)
  to install Config Sync if it is not set up yet.
- Install [Helm](https://helm.sh/) to render the manifests.
- [Install the `nomos` command](https://cloud.google.com/anthos-config-management/docs/how-to/nomos-command#installing)

## Preparing the Git repository

### Set up a git repository
You can fork the repository to your local workstation, or create a new one with the following steps:
- [Create a new repository](https://docs.github.com/en/github/getting-started-with-github/create-a-repo)
- Create a directory that contains the configuration that you want to sync to and add a README.md file in the directory.
  ```console
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
You can download the helm chart locally and render the manifests upon your local chart.
```console
# Add the helm chart repository
helm repo add cert-manager https://charts.jetstack.io

# Download the chart and unpack it in the local directory.
helm pull cert-manager/cert-manager --version 1.3.0 --untar

# Render the template and write the rendered manifests into an output directory.
helm template my-cert-manager cert-manager --namespace cert-manager --output-dir manifests
```
  
### Commit the changes to the repository:
```console
git add .
git commit -m 'Set up cert-manager manifests.'
git push
```
   
## Configuring syncing from the Git repository

You can configure syncing from the Git repository using GCP console or gcloud.

### Using GCP Console

Following the console instructions for
[configuring Config Sync](https://cloud.google.com/anthos-config-management/docs/how-to/installing-config-sync#configuring-config-sync),
you need to

- Select **None** in the **Git Repository Authentication for ACM** section
- Select **Enable Config Sync** in the **ACM settings for your clusters** section
   - If you're using your forked repo, the **URL** should be the Git repository url for your fork: `https://github.com/<YOUR_ORGANIZATION>/anthos-config-management-samples.git`; otherwise the **URL** should be `https://github.com/GoogleCloudPlatform/anthos-config-management-samples.git`
   - the **Branch** should be `master`.
   - the **Tag/Commit** should be `HEAD`.
   - the **Source format** field should **unstructured**.
   - the **Policy directory** field should be `helm-component/manual-rendering/manifests`.

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
     sourceFormat: unstructured
     git:
       syncRepo: https://github.com/GoogleCloudPlatform/anthos-config-management-samples/
       syncBranch: master
       secretType: none
       policyDir: helm-component/manual-rendering/manifests
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

You can also check if the helm component is successfully installed by running
```console
kubectl get all -n cert-manager
```

## Uninstalling the component
In order to help prevent accidental deletion, Config Sync does not allow you to remove all namespaces or
cluster-scoped resources in a single commit.
Follow the instructions to gracefully uninstall the component and remove the namespace in separate commits.
- Remove the cert-manager component.
  ```console
  git rm -rf manifests/cert-manager && git commit -m "uninstall cert-manager" && git push origin init
  ````
- Delete the cert-manager namespace.
  ```console
  git rm manifests/namespace-cert-manager.yaml && git commit -m "remove the cert-manager namespace" && git push origin init
  ````
- Verify the namespace does not exist.
  ```console
  Kubectl get namespace cert-namespace
  ```
