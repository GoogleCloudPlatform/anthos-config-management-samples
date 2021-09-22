#  Using ConfigSync with Multiple Environments

This guide shows you how to set up Config Sync for GKE across two environments using the automated rendering feature in Config Sync versions 1.9.0 or later. 

## Overview 

In this scenario, you're part of a platform admin team at Foo Corp.
The Foo Corp applications are deployed to GKE, with resources divided across two projects, `dev` and `prod`.
The `dev` project contains a development GKE cluster, and the `prod` project contains the production GKE cluster.
Your goal as the platform admin is to ensure that both environments stay within compliance of Foo Corp's policies,
and that base level resources - like Kubernetes namespaces and service accounts- remain consistent across both environments. 

You'll set up the following:

- 2 Google Cloud projects representing `dev` and `prod` environments
- 2 GKE clusters, `dev` and `prod`, in the separate projects
- ConfigSync 1.9.0+ installed to both clusters - the dev cluster, and the prod cluster. Both of the clusters are synced to `foo-config-source`.
- Optional. You can configure your clusters to sync from the example directly.
  If you want to make local changes to your configs, you can fork the repo and push changes to your fork.
  The following instruction uses this repo as an example


If you navigate into ../config-source/, you can see the `base/` manifests and the `dev/` and `prod/` kustomize overlays.
Each directory contains a `kustomization.yaml` file, which lists the files kustomize should manage and apply to the cluster.
Notice that in `dev/kustomization.yaml` and `prod/kustomization.yaml` that a series of patches are defined,
which manipulate the `base/` resources for that specific environment.
For instance, the dev `RoleBinding` allows all FooCorp developers to deploy pods to the dev cluster,
whereas the prod `RoleBinding` only allows a Continuous Deployment agent, `deploy-bot@foo-corp.com`, to deploy pods into production.

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


## Prerequisites 

- 2 Google Cloud projects
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [nomos](https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/nomos-command) 

  
## Steps 

1. **Set variables**. 

```
export DEV_PROJECT=""
export PROD_PROJECT=""
export DEV_CLUSTER_ZONE=""
export PROD_CLUSTER_ZONE=""
```

2. **Create 1 GKE cluster in each of the 2 projects.** This script also enables the GKE and Anthos APIs, and connects to your dev and prod clusters so that you can access their APIs with `kubectl`. 

```
../external-rendering/1-create-clusters.sh
```

Expected output: 

```
kubeconfig entry generated for dev.
Fetching cluster endpoint and auth data.
kubeconfig entry generated for prod.
⭐️ Done creating clusters.
```

3. **Register clusters to separate Anthos environments.** This script creates a Google Cloud service account and key for Anthos cluster registration, then uses the `gcloud container hub memberships register` command to register the `dev` and `prod` clusters to Anthos in their own projects.

```
../external-rendering/2-register-clusters.sh
```

Expected output: 

```
Waiting for Feature Config Management to be created...done.
⭐️ Done registering clusters.
```

4. **Install Config Sync** on both clusters. This script updates the ConfigManagement CRD resources in the `install-config/` directory to point to your `dev` and `prod` directories (for the dev and prod clusters, respectively), then uses the `gcloud alpha container hub config-management apply` to install Config Sync on both clusters, using the `install-config/` resources as configuration.

```
echo "🔁 Installing ConfigSync on the dev cluster..."
gcloud config set project $DEV_PROJECT
kubectl config use-context $DEV_CTX
gcloud alpha container hub config-management apply \
    --membership=dev \
    --config="install-config/config-management-dev.yaml" \
    --project=${DEV_PROJECT}

echo "🔁 Installing ConfigSync on the prod cluster..."
gcloud config set project $PROD_PROJECT
kubectl config use-context $PROD_CTX
gcloud alpha container hub config-management apply \
    --membership=prod \
    --config="install-config/config-management-prod.yaml" \
    --project=${PROD_PROJECT}
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

5.  **Run `nomos status`.** You should see that both your dev and prod clusters are now `synced` to their respective repos. It may take a few minutes for the `SYNCED` status to appear. It's normal to see status errors like `rootsyncs.configsync.gke.io "root-sync" not found` or `KNV2009: Internal error occurred: failed calling webhook`, while Config Sync is setting up.

```
gke_megan-dev4_us-east1-b_dev
  --------------------
  <root>   https:/github.com/GoogleCloudPlatform/anthos-config-management-samples/multi-environments-kustomize/config-source/overlays/dev@main
  SYNCED   9890b706

*gke_megan-prod4_us-central1-b_prod
  --------------------
  <root>   https:/github.com/GoogleCloudPlatform/anthos-config-management-samples/multi-environments-kustomize/config-source/overlays/prod@main
  SYNCED   5e5cf84f
```

6. **Switch to the `dev` cluster context.** Get namespaces to verify that the resources are synced - you should see the `foo` namespace appear. 


```
kubectl config use-context "gke_${DEV_PROJECT}_${DEV_CLUSTER_ZONE}_dev"
kubectl get namespace 
```

Expected output: 

```
NAME                           STATUS   AGE
config-management-monitoring   Active   2m7s
config-management-system       Active   2m7s
default                        Active   13m
foo                            Active   98s
gke-connect                    Active   12m
kube-node-lease                Active   13m
kube-public                    Active   13m
kube-system                    Active   13m
resource-group-system          Active   119s
```

Congrats! You just set up automated config rendering for a dev and prod environment, across multiple Google Cloud projects and environments. 

### Cleanup 

To delete the resources created by this guide, but to keep both the dev and prod projects intact, run the cleanup script. 

```
echo "Turning off Anthos Config Management.."
gcloud config set project $DEV_PROJECT
gcloud alpha container hub config-management disable 

gcloud config set project $PROD_PROJECT
gcloud alpha container hub config-management disable 


echo "Deleting GKE clusters..."
gcloud container clusters delete --quiet --project=${DEV_PROJECT} dev --zone=${DEV_CLUSTER_ZONE} --async 
gcloud container clusters delete --quiet --project=${PROD_PROJECT} prod --zone=${PROD_CLUSTER_ZONE} --async
```

### Learn More 

- [Anthos docs - Introducing Environs](https://cloud.google.com/anthos/multicluster-management/environs)
- [Safe Rollouts with Anthos Config Management](https://cloud.google.com/architecture/safe-rollouts-with-anthos-config-management) 
- [Using Policy Controller in a CI Pipeline](https://cloud.google.com/anthos-config-management/docs/tutorials/policy-agent-ci-pipeline)
- [Best Practices for Policy Management Using Anthos Config Management](https://cloud.google.com/solutions/best-practices-for-policy-management-with-anthos-config-management)
