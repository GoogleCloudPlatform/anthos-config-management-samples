# Sample OCI Image Signature Verification with Config Sync

This sample demonstrates how to verify the signature of an OCI image that Config
Sync is managing. The webhook monitors the configsync.gke.io/image-to-sync
annotation on specified RootSync or RepoSync resources, which contains the full
URL of the image to sync. By comparing the previous and updated values in the
admission review request, the webhook can detect if a new image has been
introduced, triggering an image verification process.

## Prerequisites

CLI: [OpenSSL], [Cosign], [Docker], [Kubectl], [Crane]

Environment: GKE cluster, Google Cloud Artifact Registry.

## Build the signature verification server

```shell
docker build -t <IMAGE_REGISTRY_URL>:latest . && docker push <IMAGE_REGISTRY_URL>:latest
```

## Create a Namespace and Kubernetes Service Account

This is intended to group everything under the same namespace. In this example, `signature-verification` is used as a reference:

```shell
kubectl create ns signature-verification
```

It is recommended to create the Kubernetes Service Account in advance to facilitate authentication in subsequent steps:

```shell
kubectl create sa signature-verification-sa -n signature-verification
```

## Authentications

### Image registry authentication

This example demonstrates how to authenticate the Cosign client within the
admission webhook using built-in Google authentication to access the source
image repository. You can adapt this authentication method to suit your specific
verification client and registry.

### IAM setup for the signature verification server

- Give the Google service account permission to read images from Artifact Registry
```shell
gcloud artifacts repositories add-iam-policy-binding <SOURCE_IMAGE_AR_REPO> \
   --location=<LOCATION> \
   --member=serviceAccount:<GSA_NAME>@<PROJECT_ID>.iam.gserviceaccount.com \
   --role=roles/artifactregistry.reader \
   --project=<PROJECT_ID>
```
- Create an IAM policy binding between the Kubernetes service account and Google service account
```shell
gcloud iam service-accounts add-iam-policy-binding \
   --role roles/iam.workloadIdentityUser \
   --member "serviceAccount:<PROJECT_ID>.svc.id.goog[signature-verification/signature-verification-sa]" \
   <GSA_NAME>@<PROJECT_ID>.iam.gserviceaccount.com \
   --project=<PROJECT_ID>
```
- Annotate the Kubernetes ServiceAccount so that GKE sees the link between the service accounts
```shell
kubectl annotate serviceaccount signature-verification-sa -n signature-verification \
"iam.gke.io/gcp-service-account=<GSA_NAME>@<PROJECT_ID>.iam.gserviceaccount.com"
```

See [Authentication to Google Cloud APIs from GKE workloads] for more details.

### Cosign keys

Generate cosign.key and cosign.pub pairs:

```shell
cosign generate-key-pair
```

Create on cluster secret:

```shell
kubectl create secret generic cosign-key --from-file=cosign.pub -n signature-verification
```

### Signature Verification Server Authentication

Generate tls.crt and tls.key:

```shell
openssl req -nodes -x509 -sha256 -newkey rsa:4096 \
-keyout tls.key \
-out tls.crt \
-days 356 \
-subj "/CN=signature-verification-service.signature-verification.svc"  \
-addext "subjectAltName = DNS:signature-verification-service,DNS:signature-verification-service.signature-verification.svc,DNS:signature-verification-service.signature-verification"
```

Create on cluster secret:

```shell
kubectl create secret tls webhook-tls --cert=tls.crt --key=tls.key -n signature-verification
```

## Deploy the signature verification server and ValidatingWebhookConfiguration

#### In signature-verification-deployment.yaml file

Replace the <PROJECT_ID> with the project name where signature verification server image is hosted.

Replace the <SIGNATURE_VERIFICATION_SERVER_IMAGE_URL> with the URL of the signature verification server image.

#### In signature-verification-validatingwebhookconfiguration.yaml file

Replace <CA_BUNDLE> with the base64-encoded content of tls.crt: `cat tls.crt | base64 -w 0`.

#### Apply the manifests to cluster.

```shell
kubectl apply -f signature-verification-deployment.yaml -n signature-verification
kubectl apply -f signature-verification-validatingwebhookconfiguration.yaml
```

## Test the image signature verification

- [Install Config Sync], configure it to [sync from an unsigned OCI image].

- Look for errors in signature verification server log `kubectl logs deployment signature-verification-server -n signature-verification`:

```angular2html
main.go:69: error during command execution: no signatures found
```

- Config Sync will also be reporting source error when running `nomos status`.

```angular2html
Error:   KNV2002: admission webhook "imageverification.webhook.com" denied the request: Image validation failed: cosign verification failed: exit status 10, output: Error: no signatures found
main.go:69: error during command execution: no signatures found
```

- Sign the same source image using Cosign

```shell
cosign sign <IMAGE> --key cosign.key
```

- Once the image is correctly signed, the signature verification server should successfully verify it. This will result in:

  - The Config Sync source error being cleared.
  - The `configsync.gke.io/image-to-sync` annotation on the RootSync object being updated to reflect the new signed image.

- You can verify this by inspecting the RootSync object
```shell
kubectl get rootsync <ROOT_SYNC_NAME> -n config-management-system -oyaml
```
Or the RepoSync object
```shell
kubectl get reposync <REPO_SYNC_NAME> -n <REPO_SYNC_NAMESPACE> -oyaml
```

[example]: https://github.com/GoogleContainerTools/kpt-config-sync/tree/main/test/docker/presync-webhook-server
[OpenSSL]: https://github.com/openssl/openssl
[Cosign]: https://github.com/sigstore/cosign
[Gcloud]: http://cloud/sdk/docs/install
[Docker]: https://docs.docker.com/engine/install/
[Kubectl]: https://kubernetes.io/docs/tasks/tools/
[Crane]: https://github.com/google/go-containerregistry/tree/main/cmd/crane
[Authentication to Google Cloud APIs from GKE workloads]: http://cloud/kubernetes-engine/docs/how-to/workload-identity
[Install Config Sync]: http://cloud/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync
[sync from an unsigned OCI image]: http://cloud/kubernetes-engine/enterprise/config-sync/docs/how-to/sync-oci-artifacts-from-artifact-registry