# Sample OCI Image Signature Verification with Config Sync

## Prerequisites

CLI: [OpenSSL], [Cosign], [Gcloud], [Docker], [Kubectl], [Crane]

Environment: GKE cluster, Google Cloud Artifact Registry repo

## Build the webhook server

```angular2html
docker build -t gcr.io/<PROJECT_ID>/webhook-server:latest . && docker push gcr.io/<PROJECT_ID>/webhook-server:latest
```

## Create a namespace

```angular2html
kubectl create ns oci-webhook
```

```angular2html
kubectl apply -f webhook-deployment.yaml
```

## Authentications

### Cosign keys

Generate cosign.key and cosign.pub

```angular2html
cosign generate-key-pair
```

Create on cluster secret:

```angular2html
kubectl create secret generic cosign-key --from-file=cosign.pub -n oci-webhook
```

### OpenSSL keys

Generate tls.crt and tls.key:

```angular2html
openssl req -nodes -x509 -sha256 -newkey rsa:4096 \
-keyout tls.key \
-out tls.crt \
-days 356 \
-subj "/CN=webhook-service.oci-webhook.svc"  \
-addext "subjectAltName = DNS:webhook-service,DNS:webhook-service.oci-webhook.svc,DNS:webhook-service.oci-webhook"
```

Create on cluster secret:

```angular2html
kubectl create secret tls webhook-tls --cert=tls.crt --key=tls.key -n oci-webhook
```

### IAM setup for the Webhook Server

- Give the Google service account associated with the webhook server permission to read images from Artifact Registry
```angular2html
gcloud artifacts repositories add-iam-policy-binding <AR_REPO> \
   --location=<LOCATION> \
   --member=serviceAccount:<GSA_NAME>@<PROJECT_ID>.iam.gserviceaccount.com \
   --role=roles/artifactregistry.reader \
   --project=<PROJECT_ID>
```
- Create an IAM policy binding between the Kubernetes service account and Google service account
```angular2html
gcloud iam service-accounts add-iam-policy-binding \
   --role roles/iam.workloadIdentityUser \
   --member "serviceAccount:<PROJECT_ID>.svc.id.goog[oci-webhook/webhook-server-sa]" \
   <GSA_NAME>@<PROJECT_ID>.iam.gserviceaccount.com \
   --project=<PROJECT_ID>
```
- Annotate the Kubernetes ServiceAccount so that GKE sees the link between the service accounts
```angular2html
kubectl annotate serviceaccount webhook-server-sa -n oci-webhook \
iam.gke.io/gcp-service-account=<GSA_NAME>@<PROJECT_ID>.iam.gserviceaccount.com
```

See [Authentication to Google Cloud APIs from GKE workloads] for more details.

## Deploy the webhook server and ValidatingWebhookConfiguration

Replace the <PROJECT_ID> in webhook-manifest.yaml with the project name where webhook server image is hosted.

Replace the <CA_BUNDLE> in the same file with the content of tls.crt `cat tls.crt | base64 -w 0`.

Apply the manifest to cluster.

```angular2html
kubectl apply -f webhook-manifeset.yaml
```

## Test the image signature verification

- [Install Config Sync], configure it to [sync from an unsigned OCI image].

- Look for errors in webhook server log `kubectl logs deployment webhook-server -n oci-webhook`:

```angular2html
main.go:69: error during command execution: no signatures found
```

- Config Sync will also be reporting source error when running `nomos status`.

```angular2html
Error:   KNV2004: admission webhook "imageverification.webhook.com" denied the request: Image validation failed: cosign verification failed: exit status 10, output: Error: no signatures found
main.go:69: error during command execution: no signatures found
```

- Sign the same source image using Cosign

```angular2html
cosign sign <IMAGE> --key cosign.key
```

- Once the image is correctly signed, the webhook server should successfully verify it. This will result in:

  - The Config Sync source error being cleared.
  - The configsync.gke.io/source-commit and configsync.gke.io/source-url annotations on the RootSync object being updated to reflect the new signed image.

- You can verify this by inspecting the RootSync object
```angular2html
kubectl get rootsync <ROOT_SYNC_NAME> -n config-management-system -oyaml
```

[OpenSSL]: https://github.com/openssl/openssl
[Cosign]: https://github.com/sigstore/cosign
[Gcloud]: http://cloud/sdk/docs/install
[Docker]: https://docs.docker.com/engine/install/
[Kubectl]: https://kubernetes.io/docs/tasks/tools/
[Crane]: https://github.com/google/go-containerregistry/tree/main/cmd/crane
[Authentication to Google Cloud APIs from GKE workloads]: http://cloud/kubernetes-engine/docs/how-to/workload-identity
[Install Config Sync]: http://cloud/kubernetes-engine/enterprise/config-sync/docs/how-to/installing-config-sync
[sync from OCI image]: http://cloud/kubernetes-engine/enterprise/config-sync/docs/how-to/sync-oci-artifacts-from-artifact-registry