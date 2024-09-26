# Multi-cluster configuration with Fleet Packages

[Fleet Packages] provides a way to deploy configuration into multiple clusters in a [fleet].

## Prerequisistes

1. [gcloud CLI], as this guide uses it to set up the necessary infrastructure and for using the Fleet Packages service.
2. A GitHub account, as we will fetch the configuration from git. Authentication to git will be set up using a GitHub App, so you must have admin-level permissions on your GitHub repository.
3. A Google Cloud project with billing and with GKE Enterprise enabled.


## Configure the environment

Create an environment variable in your shell that identifies the project you want to use:

```
PROJECT_ID=<MY_PROJECT>
```

Also set the current project in gcloud to the same project:

```
gcloud config set project $PROJECT_ID
```

If you want to use your current project, you can set the environment variable with:

```
PROJECT_ID=$(gcloud config get-value project)
```

## Install Config Sync across the fleet

Fleet Packages is built on top of Config Sync, so we need to install Config Sync on all clusters.

Create the apply-spec:

```
cat << EOF > apply-spec.yaml
applySpecVersion: 1
spec:
  configSync:
    enabled: true
EOF
```

Enable the config-management feature on the fleet and set it up to install Config Sync on all new clusters:

```
gcloud beta container fleet config-management enable --fleet-default-member-config=apply-spec.yaml --project=$PROJECT_ID
```


## Set up a fleet

We need a few GKE clusters registered to a fleet. We only create two clusters here to keep things simple.


Create a cluster in us-west:
```
gcloud container clusters create fp-quickstart-cluster-west --project=$PROJECT_ID --zone=us-west2-a --workload-pool=$PROJECT_ID.svc.id.goog --enable-fleet --async
```

Create a cluster in us-east:
```
gcloud container clusters create fp-quickstart-cluster-east --project=$PROJECT_ID --zone=us-east1-c --workload-pool=$PROJECT_ID.svc.id.goog --enable-fleet --async
```

It will take a few minutes for the clusters to be ready. You can continue with the next steps and there is a later step to verify that they are ready.


## Configure Cloud Build Repositories

We have a sample package at https://github.com/GoogleCloudPlatform/anthos-config-management-samples/tree/main/fleet-packages-quickstart/config. This is a simple example that just sets up nginx. Fork this repo into your own GitHub account.

Fleet Packages leverages [Cloud Build Repositories] (2nd gen) for connecting to git. It sets up authentication with a GitHub App, which requires admin-level permissions on your GitHub org/user. Therefore, you must be using your own fork of the example repository.

Follow these steps to set it up:

1. Enable the Cloud Build and Secret Manager APIs. Secret Manager is used by Cloud Build Repositories for managing the credentials for the GitHub App.
```
gcloud services enable cloudbuild.googleapis.com --project=$PROJECT_ID
gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID
```

2. Verify the IAM permissions as described in https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github?generation=2nd-gen#iam_perms.

3. Create a connection to your GitHub host using the steps described in https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github?generation=2nd-gen#connecting_a_github_host. You can use either the console or gcloud. You must use the region `us-central1` and we suggest using the name `fp-quickstart` for the connection (the rest of the guide will use this name).

4. Connect to the forked GitHub repository using the steps described in https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github?generation=2nd-gen#connecting_a_github_repository_2. You can use either the console or gcloud. Again, you must use the region `us-central1`, connection name `fp-quickstart`, and we suggest using the name `anthos-config-management-samples` for the repository.

5. We will need the fully qualified name for the repository a little later. With the suggested names, it will be:

```
projects/$PROJECT_ID/locations/us-central1/connections/fp-quickstart/repositories/anthos-config-management-samples
```

If you are uncertain about then names, you can list these with gcloud using the following commands:

List all connections:

```
gcloud builds connections list --region=us-central1 --project=$PROJECT_ID
```

List all repositories for a specific connection:

```
gcloud builds repositories list --region=us-central1 --connection=<CONNECTION_NAME>
```

## Configure a Service Account

Create a service account:

```
gcloud iam service-accounts create fp-quickstart-sa
```

Add an IAM policy binding for the [ResourceBundle Publisher] role:

```
gcloud projects add-iam-policy-binding $PROJECT_ID \
   --member="serviceAccount:fp-quickstart-sa@$PROJECT_ID.iam.gserviceaccount.com" \
   --role='roles/configdelivery.resourceBundlePublisher' \
   --condition=None
```

Add an IAM policy binding for the [Logs Writer] role:

```
gcloud projects add-iam-policy-binding $PROJECT_ID \
   --member="serviceAccount:fp-quickstart-sa@$PROJECT_ID.iam.gserviceaccount.com" \
   --role='roles/logging.logWriter' \
   --condition=None
```

## Verify that clusters are ready

To verify that the clusters are ready, check that they are marked at `RUNNING` when running this command:

```
gcloud container clusters list --project=$PROJECT_ID
```

Also check that Config Sync has been installed on both clusters. If both clusters are listed, they should have Config Sync installed.

```
gcloud beta container fleet config-management status --project=$PROJECT_ID
```

## Create a FleetPackage

Enable the Config Delivery API:

```
gcloud services enable configdelivery.googleapis.com --project=$PROJECT_ID
```

Create a file with the FleetPackage spec in yaml format:

```
cat << EOF > fp-spec.yaml
resourceBundleSelector:
  cloudBuildRepository:
    name: projects/$PROJECT_ID/locations/us-central1/connections/fp-quickstart/repositories/anthos-config-management-samples
    tag: v1.0.0
    serviceAccount: projects/$PROJECT_ID/serviceAccounts/fp-quickstart-sa@$PROJECT_ID.iam.gserviceaccount.com
    path: fleet-packages-quickstart/config
target:
  fleet:
    project: projects/$PROJECT_ID
rolloutStrategy:
  rolling:
    maxConcurrent: 1
EOF
```

Create the FleetPackage:

```
gcloud alpha container fleet packages create fp-nginx \
    --source=fp-spec.yaml \
    --project=$PROJECT_ID \
    --location=us-central1
```

Note that this can take up to a few minutes the first time this command is called in a project.

Check the Fleet Package:

```
gcloud alpha container fleet packages list --project=$PROJECT_ID --location=us-central1
```

It will take a minute or two before the rollout starts. The following command shows all rollouts for the given FleetPackage:

```
gcloud alpha container fleet packages rollouts list --fleet-package=fp-nginx --project=$PROJECT_ID --location=us-central1
```

To see details about a specific rollout, including when each cluster was updated, run the following command. The names of rollouts are shown in the output from the previous command.

```
gcloud alpha container fleet packages rollouts describe <ROLLOUT_NAME> --fleet-package=fp-nginx --project=$PROJECT_ID --location=us-central1
```

# Cleanup

These are instructions for cleaning up the resources created for this guide. Please only use these commands if you are not using these resources for other purposes than this guide.

Delete the FleetPackage:

```
gcloud alpha container fleet packages delete fp-nginx --force --project=$PROJECT_ID
```

Delete the Service Account:

```
gcloud iam service-accounts delete fp-quickstart-sa@$PROJECT_ID.iam.gserviceaccount.com --project=$PROJECT_ID
```

Delete the Cloud Build Repositories repository and connection

```
gcloud builds repositories delete anthos-config-management-samples --connection=fp-quickstart --region=us-central1 --project=$PROJECT_ID
gcloud builds connections delete fp-quickstart --region=us-central1 --project=$PROJECT_ID
```

Delete the GKE clusters:

```
gcloud container clusters delete fp-quickstart-cluster-west --project=$PROJECT_ID --zone=us-west2-a --async
gcloud container clusters delete fp-quickstart-cluster-east --project=$PROJECT_ID --zone=us-east1-c --async
```

Disable the ACM feature:

```
gcloud beta container fleet config-management disable --project=$PROJECT_ID
```

[Fleet Packages]: https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/how-to/fleet-packages
[Cloud Build Repositories]: https://cloud.google.com/build/docs/repositories
[Logs Writer]: https://cloud.google.com/iam/docs/understanding-roles#logging.logWriter
[fleet]: https://cloud.google.com/kubernetes-engine/fleet-management/docs
[gcloud CLI]: https://cloud.google.com/sdk/docs/install
[ResourceBundle Publisher]: https://cloud.google.com/iam/docs/understanding-roles#configdelivery.resourceBundlePublisher
