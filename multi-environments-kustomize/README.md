#  Using ConfigSync with Multiple Environments

This guide shows you how to set up Config Sync for GKE across two environments using config management best practices. 

## Overview 

In this scenario, you're part of a platform admin team at Foo Corp. The Foo Corp applications are deployed to GKE, with resources divided across two projects, `dev` and `prod`. The `dev` project contains a development GKE cluster, and the `prod` project contains the production GKE cluster. Your goal as the platform admin is to ensure that both environments stay within compliance of Foo Corp's policies, and that base level resources - like Kubernetes namespaces and service accounts- remain consistent across both environments. 

![](screenshots/architecture.png)

You'll set up the following: 

- 2 Google Cloud projects representing `dev` and `prod` environments 
- 2 GKE clusters, `dev` and `prod`, in the separate projects
- 3 GitHub repos, `foo-config-source`, `foo-config-dev`, and `foo-config-prod`. These are ConfigSync unstructured repos containing YAML config. 
- ConfigSync installed to both clusters - the dev cluster synced to `foo-config-dev`, the prod cluster synced to `foo-config-prod`. 
- 3 Secret Manager secrets with your Git username and a developer token, used by Cloud Build to commit to those Github repos 
- A Cloud Build pipeline, triggered on pushed to the `foo-config-source`. This pipeline uses `kustomize build` to render customized `foo-config-dev` and `foo-config-prod` repos with YAML config, using the "Base" and "overlays" in `foo-config-source`. These kustomize overlays have been provided to you in `config-source/`. 

## Prerequisites 

- GitHub account 
- 2 Google Cloud projects
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [nomos](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/nomos-command) 

  
## Steps 

1. **Create a GitHub personal access token**. [Follow the instructions here](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) to create a token. Give the token full `repo` permissions, as well as `delete_repo` permissions (if you plan to run the cleanup script at the end of this guide). Then click **Generate Token.** Copy the value of the token to your clipboard.

![screenshot](screenshots/gh-token-create.png)

2. **Set variables**, using the copied value of your personal access token as the value of the `GITHUB_TOKEN` below. 

```
export DEV_PROJECT=""
export PROD_PROJECT=""
export DEV_CLUSTER_ZONE=""
export PROD_CLUSTER_ZONE=""
export GITHUB_USERNAME=""
export GITHUB_TOKEN=""
export GITHUB_EMAIL=""
```

3. **Configure your local Git for your GitHub username and email.** 

```
git config --global user.name $GITHUB_USERNAME
git config --global user.email $GITHUB_EMAIL
git config --global credential.helper store
git config --global credential.helper cache
```

4. **Create 1 GKE cluster in each of the 2 projects.** This script also enables the GKE and Anthos APIs, and connects to your dev and prod clusters so that you can access their APIs with `kubectl`. 

```
./1-create-clusters.sh
```

Expected output: 

```
kubeconfig entry generated for dev.
Fetching cluster endpoint and auth data.
kubeconfig entry generated for prod.
⭐️ Done creating clusters.
```

5. **Register clusters to separate Anthos environments.** This script creates a Google Cloud service account and key for Anthos cluster registration, then uses the `gcloud container hub memberships register` command to register the `dev` and `prod` clusters to Anthos in their own projects.

```
./2-register-clusters.sh
```

Expected output: 

```
Waiting for Feature Config Management to be created...done.
⭐️ Done registering clusters.
```

6. **Create Github repos in your account.** This script creates three Github repos: `foo-config-source`, `foo-config-dev`, and `foo-config-prod`. Users will commit config to the `source` repo, and a CI pipeline (that we'll create in a few steps) will render config to the other two repos, using dev- and prod-specific values. From there, the `dev` cluster will sync from `foo-config-dev`, and the `prod` cluster will sync from `foo-config-prod`. 

**Note** - if you are prompted for your Git credentials here, use your `GITHUB_TOKEN` value as your password, not your Github password. 

```
./3-create-repos.sh
```

Expected output (for each repo): 

```
😸 Creating foo-config-prod repo...
{
  "id": 364312792,
  "node_id": "MDEwOlJlcG9zaXRvcnkzNjQzMTI3OTI=",
  "name": "foo-config-prod",
 ...
}
Cloning into 'foo-config-prod'...
warning: You appear to have cloned an empty repository.
[main (root-commit) b681a3d] Initialize
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 README.md
Enumerating objects: 3, done.
Counting objects: 100% (3/3), done.
Writing objects: 100% (3/3), 211 bytes | 211.00 KiB/s, done.
Total 3 (delta 0), reused 0 (delta 0), pack-reused 0
To https://github.com/askmeegs/foo-config-prod.git
 * [new branch]      main -> main
```

If you navigate to github.com/[your-github-username]/foo-config-source, you should see a repo populated with two directories, `base/` and `overlays/`. 

7. **Run the secret manager script** to create Github secrets corresponding to your Github auth info. This will allow Cloud Build to push to Github on your behalf. (The Cloud Build pipeline  you'll set up next gets your Github auth info directly from Secret Manager.)

```
./4-secret-manager-git.sh
```

Expected output: 

```
🔐 Creating secret manager secrets in prod project...
Created secret [github-username].
Created version [1] of the secret [github-username].
Created secret [github-email].
Created version [1] of the secret [github-email].
Created secret [github-token].
Created version [1] of the secret [github-token].
✅ Granting Cloud Build secret manager access...
Project number is: ########
Updated IAM policy for project [project-id].
```

8. **View the Cloud Build pipeline.** This pipeline uses kustomize to render dev and prod manifests using the manifests in the `base/` directory.

```
cat foo-config-source/cloudbuild.yaml 
```

Expected output (truncated): 

```
steps: 
- name: 'gcr.io/google-samples/cloudbuild-kustomize:latest'
  id: Render foo-config-dev 
  entrypoint: 'bash'
  args:
  - '-eEuo'
  - 'pipefail'
  - '-c'
  - |-
    git clone https://github.com/$$GITHUB_USERNAME/foo-config-dev && \
    cd foo-config-dev 
    git config user.email $$GITHUB_EMAIL
    git config user.name $$GITHUB_USERNAME 
    git remote set-url origin https://$$GITHUB_USERNAME:$$GITHUB_TOKEN@github.com/$$GITHUB_USERNAME/foo-config-dev.git
    cd ..

    kustomize build overlays/dev --output foo-config-dev/
    cd foo-config-dev 

    rm README.md 
    echo "Update: ${SHORT_SHA}" > README.md

    git add . && \
    git commit -m "Rendered: ${SHORT_SHA}
    Built from commit ${COMMIT_SHA} of repository foo-config-source - main branch 
    Author: $(git log --format='%an <%ae>' -n 1 HEAD)" && \
    git push origin main
  secretEnv: ['GITHUB_EMAIL', 'GITHUB_USERNAME', 'GITHUB_TOKEN']
- name: 'gcr.io/google-samples/cloudbuild-kustomize:latest'
  id: Render foo-config-prod
```

If you navigate into foo-config-source/, you can see the `base/` manifests and the `dev/` and `prod/` kustomize overlays used by this pipeline. Each directory contains a `kustomization.yaml` file, which lists the files kustomize should manage and apply to the cluster. Notice that in `dev/kustomization.yaml` and `prod/kustomization.yaml` that a series of patches are defined, which manipulate the `base/` resources for that specific environment. For instance, the dev `RoleBinding` allows all FooCorp developers to deploy pods to the dev cluster, whereas the prod `RoleBinding` only allows a Continuous Deployment agent, `deploy-bot@foo-corp.com`, to deploy pods into production. 

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../../base
patches:
# ServiceAccount - make name unique per environ 
- target:
    kind: ServiceAccount
    name: foo-ksa
  patch: |-
    - op: replace
      path: /metadata/name
      value: foo-ksa-dev
    - op: replace
      path: /metadata/namespace
      value: foo-dev
# Pod creators - give all FooCorp developers access 
- target:
    kind: RoleBinding
    name: pod-creators
  patch: |-
    - op: replace
      path: /subjects/0/name
      value: developers-all@foo-corp.com
commonLabels:
  environment: dev
  ```

**Note** - this demo shows a simple pipeline that renders both the `dev` and `prod` manifests at the same time. In a live production environment, you would want to shield the production environment from potential bad config, through automated testing, human reviews, the use of a Code Owners file, and PolicyController checks in CI. See the [Safe Rollouts with Anthos Config Management Guide](https://cloud.google.com/architecture/safe-rollouts-with-anthos-config-management) and the [Policy Controller + Continuous Integration](https://cloud.google.com/anthos-config-management/docs/tutorials/policy-agent-ci-pipeline) guide for more information. 


9. **Open the Cloud Console in your prod project, and navigate to Cloud Build**. Click Triggers > Manage Repositories > Connect Repository. Check the `foo-config-source` repo, then click **Done.** 


10. **From the Cloud Build dashboard, create a Trigger** from the `foo-config-source` repo with the following fields: 

- **Trigger name**: Foo-Config-Render
- **Event**: push to a new branch
- **Repository**: foo-config-source
- **Branch**: `^main$`
- **Type**: Autodetected (`cloudbuild.yaml`)

Click **Create**. 

11. Because we already pushed `cloudbuild.yaml` to the foo-config-source repo before creating this trigger, **let's run it manually to trigger the rendering of the dev and prod repos**. In the triggers list, in the `Foo-Config-Render` row, click **Run** on the right side of the screen and use the default branch value, `main`. The build should run successfully, writing the output of `kustomize build` to the `foo-config-dev` and `foo-config-prod` repos, respectively. 

![](screenshots/build-success.png)

12. **Once the build completes, open one of the dev or prod repos.** You should see YAML files populating the repo, and a README update indicating the commit SHA of the `foo-config-source` repo that this repo was last built from. 

![screenshot](screenshots/git-output.png)

13. **Install Config Sync** on both clusters. This script updates the ConfigManagement CRD resources in the `install-config/` directory to point to your `foo-config-dev` and `foo-config-prod` repos (for the dev and prod clusters, respectively), then uses the `gcloud alpha container hub config-management apply` to install Config Sync on both clusters, using the `install-config/` resources as configuration.

```
./5-install-config-sync.sh
```

Expected output: 

```
🔁 Installing ConfigSync on the dev cluster...
Updated property [core/project].
Switched to context "gke_megan-dev4_us-east1-b_dev".
Waiting for Feature Config Management to be updated...done.

...

🔁 Installing ConfigSync on the prod cluster...
Updated property [core/project].
Switched to context "gke_megan-prod4_us-central1-b_prod".
Waiting for Feature Config Management to be updated...done.
```

13.  **Run `nomos status`.** You should see that both your dev and prod clusters are now `synced` to their respective repos. It may take a few minutes for the `SYNCED` status to appear. It's normal to see status errors like `rootsyncs.configsync.gke.io "root-sync" not found` or `KNV2009: Internal error occurred: failed calling webhook`, while Config Sync is setting up.

```
gke_megan-dev4_us-east1-b_dev
  --------------------
  <root>   https:/github.com/askmeegs/foo-config-dev@main
  SYNCED   9890b706

*gke_megan-prod4_us-central1-b_prod
  --------------------
  <root>   https:/github.com/askmeegs/foo-config-prod@main
  SYNCED   5e5cf84f
```

14. **Switch to the `dev` cluster context.** Get namespaces to verify that the resources are synced - you should see the `foo-dev` namespace appear, synced from the `foo-config-dev` repo. 


```
kubectl config use-context "gke_${DEV_PROJECT}_${DEV_CLUSTER_ZONE}_dev"
kubectl get namespace 
```

Expected output: 

```
NAME                           STATUS   AGE
config-management-monitoring   Active   86m
config-management-system       Active   86m
default                        Active   102m
foo-dev                        Active   9m42s
gke-connect                    Active   98m
kube-node-lease                Active   102m
kube-public                    Active   102m
kube-system                    Active   102m
```

Congrats! You just set up automated config rendering for a dev and prod environment, across multiple Google Cloud projects and environments. 

### Cleanup 

To delete the resources created by this guide, but to keep both the dev and prod projects intact, run the cleanup script. 

```
./cleanup.sh
```

Then, delete your Cloud Build trigger in the Google Cloud Console, by clicking on the three dots to the right of the trigger name, and click **Delete.** 

### Learn More 

- [Anthos docs - Introducing Environs](https://cloud.google.com/anthos/multicluster-management/environs)
- [Kustomize documentation](https://kubernetes-sigs.github.io/kustomize/)
- [Safe Rollouts with Anthos Config Management](https://cloud.google.com/architecture/safe-rollouts-with-anthos-config-management) 
- [Using Policy Controller in a CI Pipeline](https://cloud.google.com/anthos-config-management/docs/tutorials/policy-agent-ci-pipeline)
- [Best Practices for Policy Management Using Anthos Config Management](https://cloud.google.com/solutions/best-practices-for-policy-management-with-anthos-config-management)