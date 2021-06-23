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
# !/bin/bash

if [[ -z "$PROD_PROJECT" ]]; then
    echo "Must provide PROD_PROJECT in environment" 1>&2
    exit 1
fi

if [[ -z "$GITHUB_USERNAME" ]]; then
    echo "Must provide GITHUB_USERNAME in environment" 1>&2
    exit 1
fi

if [[ -z "$GITHUB_EMAIL" ]]; then
    echo "Must provide GITHUB_EMAIL in environment" 1>&2
    exit 1
fi

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Must provide GITHUB_TOKEN in environment" 1>&2
    exit 1
fi

gcloud config set project $PROD_PROJECT 

echo "🔐 Creating secret manager secrets in prod project..."
gcloud secrets create github-username --replication-policy="automatic"
printf $GITHUB_USERNAME | gcloud secrets versions add github-username --data-file=-

gcloud secrets create github-email --replication-policy="automatic"
printf $GITHUB_EMAIL | gcloud secrets versions add github-email --data-file=-

gcloud secrets create github-token --replication-policy="automatic"
printf $GITHUB_TOKEN | gcloud secrets versions add github-token --data-file=-

echo "✅ Granting Cloud Build secret manager access..."
PROJECT_NUMBER=`gcloud projects list --filter="$PROD_PROJECT" --format="value(PROJECT_NUMBER)"`
echo "Project number is: ${PROJECT_NUMBER}"
gcloud projects add-iam-policy-binding ${PROD_PROJECT} \
    --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
    --role='roles/secretmanager.secretAccessor'

