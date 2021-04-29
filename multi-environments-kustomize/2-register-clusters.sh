# !/bin/bash

if [[ -z "$DEV_PROJECT" ]]; then
    echo "Must provide DEV_PROJECT in environment" 1>&2
    exit 1
fi

if [[ -z "$PROD_PROJECT" ]]; then
    echo "Must provide PROD_PROJECT in environment" 1>&2
    exit 1
fi

if [[ -z "$DEV_CLUSTER_ZONE" ]]; then
    echo "Must provide DEV_CLUSTER_ZONE in environment" 1>&2
    exit 1
fi

if [[ -z "$PROD_CLUSTER_ZONE" ]]; then
    echo "Must provide PROD_CLUSTER_ZONE in environment" 1>&2
    exit 1
fi

export MEMBERSHIP_NAME="anthos-membership"
export SERVICE_ACCOUNT_NAME="register-sa"


echo "🏁 Setting up project: ${DEV_PROJECT}"

echo "🔑 Creating cluster registration service account..."
gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} --project=${DEV_PROJECT}

gcloud projects add-iam-policy-binding ${DEV_PROJECT} \
 --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${DEV_PROJECT}.iam.gserviceaccount.com" \
 --role="roles/gkehub.connect"

echo "🔑 Downloading service account key..."
gcloud iam service-accounts keys create dev-key.json \
  --iam-account=${SERVICE_ACCOUNT_NAME}@${DEV_PROJECT}.iam.gserviceaccount.com \
  --project=${DEV_PROJECT}

URI="https://container.googleapis.com/v1/projects/${DEV_PROJECT}/zones/${DEV_CLUSTER_ZONE}/clusters/dev"
gcloud container hub memberships register dev \
    --project=${DEV_PROJECT} \
    --gke-uri=${URI} \
    --service-account-key-file=dev-key.json

gcloud config set project $DEV_PROJECT
gcloud alpha container hub config-management enable

echo "🏁 Setting up project: ${PROD_PROJECT}"

echo "🔑 Creating cluster registration service account..."
gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} --project=${PROD_PROJECT}

gcloud projects add-iam-policy-binding ${PROD_PROJECT} \
 --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROD_PROJECT}.iam.gserviceaccount.com" \
 --role="roles/gkehub.connect"

echo "🔑 Downloading service account key..."
gcloud iam service-accounts keys create prod-key.json \
  --iam-account=${SERVICE_ACCOUNT_NAME}@${PROD_PROJECT}.iam.gserviceaccount.com \
  --project=${PROD_PROJECT}

URI="https://container.googleapis.com/v1/projects/${PROD_PROJECT}/zones/${PROD_CLUSTER_ZONE}/clusters/prod"
gcloud container hub memberships register prod \
    --project=${PROD_PROJECT} \
    --gke-uri=${URI} \
    --service-account-key-file=prod-key.json

gcloud config set project $PROD_PROJECT
gcloud alpha container hub config-management enable

echo "⭐️ Done registering clusters."