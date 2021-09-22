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
#!/bin/bash

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

echo "🌏 Enabling APIs..."
gcloud services enable \
--project=${DEV_PROJECT} \
container.googleapis.com \
anthos.googleapis.com \
gkeconnect.googleapis.com \
gkehub.googleapis.com \
cloudresourcemanager.googleapis.com

gcloud services enable \
--project=${PROD_PROJECT} \
container.googleapis.com \
anthos.googleapis.com \
gkeconnect.googleapis.com \
gkehub.googleapis.com \
secretmanager.googleapis.com \
cloudbuild.googleapis.com \
cloudresourcemanager.googleapis.com

echo "☸️ Creating clusters..."
gcloud beta container clusters create dev \
--project=${DEV_PROJECT} --zone=${DEV_CLUSTER_ZONE} \
--machine-type=e2-standard-4 --num-nodes=4 --async 

gcloud beta container clusters create prod \
--project=${PROD_PROJECT} --zone=${PROD_CLUSTER_ZONE} \
--machine-type=e2-standard-4 --num-nodes=4 

echo "⏬ Connecting to clusters from local environment..."
gcloud container clusters get-credentials dev --zone ${DEV_CLUSTER_ZONE} --project ${DEV_PROJECT}

gcloud container clusters get-credentials prod --zone ${PROD_CLUSTER_ZONE} --project ${PROD_PROJECT}

echo "⭐️ Done creating clusters."
