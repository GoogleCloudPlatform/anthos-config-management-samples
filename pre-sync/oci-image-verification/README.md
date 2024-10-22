# Sample OCI Image Signature Verification with Config Sync

This sample demonstrates how to verify the image signature of the OCI image that Config Sync is syncing.

For one way of authenticating the image registry, this sample uses the `cosign login` command with a token stored in a Kubernetes secret. Token can be expired, user could also build a custom authentication mechanism.

This sample is implemented in a generic way so that it could be hooked into different types of image verification tools. It is implemented as a Kubernetes admission webhook server, which watches the RootSync or RepoSync resources and validates the image URL and digest SHA in the annotation metadata.

For another example tailored for Cosign integration, please see the example in the Config Sync repository.

## Prerequisites

CLI: [OpenSSL], [Cosign], [Gcloud], [Docker], [Kubectl], [Crane]

Environment: GKE cluster, Google Cloud Artifact Registry repo

## Build the signature verification server

```bash
docker build -t <IMAGE_REGISTRY_URL>:latest . && docker push <IMAGE_REGISTRY_URL>:latest
```

## Create a Namespace and Kubernetes Service Account

This is intended to group everything under the same namespace. In this example, `oci-webhook` is used as a reference:

```bash
kubectl create ns oci-webhook
```

It is recommended to create the Kubernetes Service Account in advance to facilitate authentication in subsequent steps:

```bash
kubectl create sa signature-verification-sa -n oci-webhook
```

## Authentications

### Cosign keys

Generate cosign.key and cosign.pub pairs:

```bash
cosign generate-key-pair
```

Create on cluster secret:

```bash
kubectl create secret generic cosign-key --from-file=cosign.pub -n oci-webhook
```

### OpenSSL keys

Generate tls.crt and tls.key:

```bash
openssl req -nodes -x509 -sha256 -newkey rsa:4096 \
-keyout tls.key \
-out tls.crt \
-days 356 \
-subj "/CN=signature-verification-service.oci-webhook.svc"  \
-addext "subjectAltName = DNS:signature-verification-service,DNS:signature-verification-service.oci-webhook.svc,DNS:signature-verification-service.oci-webhook"
```

Create on cluster secret:

```bash
kubectl create secret tls webhook-tls --cert=tls.crt --key=tls.key -n oci-webhook
```

### Image registry authentication

In this example, we use a token to authorize Cosign with the Docker registry. The token is retrieved from a Kubernetes secret within the cluster, and the server will fail to start if the token is not present.

```bash
TOKEN=$(gcloud auth print-access-token)

kubectl create secret generic registry-token \
  --namespace oci-webhook \
  --from-literal=token=$TOKEN
```

### IAM setup for the signature verificiation server

- Give the Google service account permission to read images from Artifact Registry
```bash
gcloud artifacts repositories add-iam-policy-binding <AR_REPO> \
   --location=<LOCATION> \
   --member=serviceAccount:<GSA_NAME>@<PROJECT_ID>.iam.gserviceaccount.com \
   --role=roles/artifactregistry.reader \
   --project=<PROJECT_ID>
```
- Create an IAM policy binding between the Kubernetes service account and Google service account
```bash
gcloud iam service-accounts add-iam-policy-binding \
   --role roles/iam.workloadIdentityUser \
   --member "serviceAccount:<PROJECT_ID>.svc.id.goog[oci-webhook/signature-verification-sa]" \
   <GSA_NAME>@<PROJECT_ID>.iam.gserviceaccount.com \
   --project=<PROJECT_ID>
```
- Annotate the Kubernetes ServiceAccount so that GKE sees the link between the service accounts
```bash
kubectl annotate serviceaccount signature-verification-sa -n oci-webhook \
"iam.gke.io/gcp-service-account=<GSA_NAME>@<PROJECT_ID>.iam.gserviceaccount.com"
```

See [Authentication to Google Cloud APIs from GKE workloads] for more details.

## Deploy the signature verification server and ValidatingWebhookConfiguration

#### In signature-verification-deployment.yaml file

Replace the <PROJECT_ID> with the project name where signature verification server image is hosted.

Replace the <SOURCE_OCI_IMAGE_REGISTRY> with the docker registry of the source OCI image.

Replace the <SIGNATURE_VERIFICATION_SERVER_IMAGE_URL> with the URL of the signature verification server image.

#### In signature-verification-validatingwebhookconfiguration.yaml file

Replace the <CA_BUNDLE> with the content of tls.crt `cat tls.crt | base64 -w 0`.

#### Apply the manifests to cluster.

```bash
kubectl apply -f signature-verification-deployment.yaml -n oci-webhook
kubectl apply -f signature-verification-validatingwebhookconfiguration.yaml
```

## Test the image signature verification

- [Install Config Sync], configure it to [sync from an unsigned OCI image].

- Look for errors in signature verification server log `kubectl logs deployment signature-verification-server -n oci-webhook`:

```angular2html
main.go:69: error during command execution: no signatures found
```

- Config Sync will also be reporting source error when running `nomos status`.

```angular2html
Error:   KNV2004: admission webhook "imageverification.webhook.com" denied the request: Image validation failed: cosign verification failed: exit status 10, output: Error: no signatures found
main.go:69: error during command execution: no signatures found
```

- Sign the same source image using Cosign

```bash
cosign sign <IMAGE> --key cosign.key
```

- Once the image is correctly signed, the signature verification server should successfully verify it. This will result in:

  - The Config Sync source error being cleared.
  - The `configsync.gke.io/source-commit` and `configsync.gke.io/source-url` annotations on the RootSync object being updated to reflect the new signed image.

- You can verify this by inspecting the RootSync object
```bash
kubectl get rootsync <ROOT_SYNC_NAME> -n config-management-system -oyaml
```
Or the RepoSync object
```bash
kubectl get reposync <REPO_SYNC_NAME> -n <REPO_SYNC_NAMESPACE> -oyaml
```

[OpenSSL]: https://github.com/openssl/openssl
[Cosign]: https://github.com/sigstore/cosign
[Gcloud]: http://cloud/sdk/docs/install
[Docker]: https://docs.docker.com/engine/install/
[Kubectl]: https://kubernetes.io/docs/tasks/tools/
[Crane]: https://github.com/google/go-containerregistry/tree/main/cmd/crane
[Authentication to Google Cloud APIs from GKE workloads]: http://cloud/kubernetes-engine/docs/how-to/workload-identity
[Install Config Sync]: http://cloud/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync
[sync from an unsigned OCI image]: http://cloud/kubernetes-engine/enterprise/config-sync/docs/how-to/sync-oci-artifacts-from-artifact-registry