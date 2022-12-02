# !/bin/bash

# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# [START anthosconfig_multi_environments_kustomize_register_clusters]

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
gcloud container fleet memberships register dev \
    --project=${DEV_PROJECT} \
    --gke-uri=${URI} \
    --service-account-key-file=dev-key.json

gcloud config set project $DEV_PROJECT
gcloud beta container fleet config-management enable

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
gcloud container fleet memberships register prod \
    --project=${PROD_PROJECT} \
    --gke-uri=${URI} \
    --service-account-key-file=prod-key.json

gcloud config set project $PROD_PROJECT
gcloud beta container fleet config-management enable

echo "⭐️ Done registering clusters."

# [END anthosconfig_multi_environments_kustomize_register_clusters]