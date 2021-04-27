#  Using ConfigSync with Multiple Environments

This guide shows you how to set up Config Sync for GKE across two environments, dev and prod, using config management best practices. 

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

- 2 Google Cloud projects
- kubectx tool 
- nomos tool 
- A Github account with a personal access token
  
## Steps 

1. **Set variables** 

```
export DEV_PROJECT=""
export PROD_PROJECT=""
export DEV_CLUSTER_ZONE=""
export PROD_CLUSTER_ZONE=""
export GITHUB_USERNAME=""
export GITHUB_TOKEN=""
export GITHUB_EMAIL=""
```

2. **Create 1 GKE cluster in each of the 2 projects.** 

```
./1-create-clusters.sh
```

3. **Register clusters to separate Anthos environments.** 

```
./2-register-clusters.sh
```

4. **Create 3 github repos.** 

```
./3-create-repos.sh
```

5. **Create secret manager secrets in the prod project with your Git credentials**. This will allow Cloud Build to push to Github on your behalf. 

```
./4-secret-manager-git.sh
```


6. **View the Cloud Build pipeline.** This pipeline uses kustomize to render dev and prod manifests using the manifests in the `base/` directory.

```
cat foo-config-source/cloudbuild.yaml 
```

Expected output: 

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
...
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



7. **Open the Cloud Console in your prod project, and navigate to Cloud Build**. Click Triggers > Manage Repositories > Connect Repository. Check the `foo-config-source` repo, then click **Done.** 


8. **From the Cloud Build dashboard, create a Trigger** from the `foo-config-source` repo with the following fields: 

- **Trigger name**: Foo-Config-Render
- **Event**: push to a new branch
- **Repository**: foo-config-source
- **Branch**: `^main$`
- **Type**: Autodetected (`cloudbuild.yaml`)

Click **Create**. 

9. Because we already pushed to the foo-config-source repo before creating this trigger, **let's run it manually to trigger the rendering of the dev and prod repos**. In the triggers list, in the `Foo-Config-Render` row, click **Run** on the right side of the screen and use the default branch value, `main`. The build should run successfully, writing the output of `kustomize build` to the `foo-config-dev` and `foo-config-prod` repos, respectively. 

![](screenshots/build-success.png)

10. **Once the build completes, open one of the dev or prod repos.** You should see YAML files populating the repo, and a README update indicating the commit SHA of the `foo-config-source` repo that this repo was last built from. 

![screenshot](screenshots/git-output.png)

11. **Install ConfigSync** on both clusters. 

```
./5-install-config-sync.sh
```

12. **Run `nomos status`.** You should see that both your dev and prod clusters are now `synced` to their respective repos. 

```
dev
  --------------------
  <root>   https:/github.com/askmeegs/foo-config-dev@main
  SYNCED   f111be7d

*prod
  --------------------
  <root>   https:/github.com/askmeegs/foo-config-prod@main
  SYNCED   f15cddf1
```

13. **Switch to the `dev` cluster.** Get namespaces to verify that the resources are synced - you should see a `foo` and `bar`  namespace appear. 


```
kubectx dev
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

### Learn More 

- [Anthos docs - Introducing Environs](https://cloud.google.com/anthos/multicluster-management/environs)
- [Kustomize documentation](https://kubernetes-sigs.github.io/kustomize/)
- [Safe Rollouts with Anthos Config Management](https://cloud.google.com/architecture/safe-rollouts-with-anthos-config-management) 
- [Using Policy Controller in a CI Pipeline](https://cloud.google.com/anthos-config-management/docs/tutorials/policy-agent-ci-pipeline)
- [Best Practices for Policy Management Using Anthos Config Management](https://cloud.google.com/solutions/best-practices-for-policy-management-with-anthos-config-management)