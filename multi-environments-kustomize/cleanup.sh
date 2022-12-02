#!/bin/bash

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

# [START anthosconfig_multi_environments_kustomize_cleanup]

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

if [[ -z "$CM_CONFIG_DIR" ]]; then
    echo "Must provide CM_CONFIG_DIR in environment" 1>&2
    exit 1
fi

echo "Turning off Anthos Config Management.."
gcloud config set project $DEV_PROJECT
gcloud beta container fleet config-management disable 

gcloud config set project $PROD_PROJECT
gcloud beta container fleet config-management disable 


echo "Deleting GKE clusters..."
gcloud container clusters delete --quiet --project=${DEV_PROJECT} dev --zone=${DEV_CLUSTER_ZONE} --async 
gcloud container clusters delete --quiet --project=${PROD_PROJECT} prod --zone=${PROD_CLUSTER_ZONE} --async

if [[ $CM_CONFIG_DIR == "cloud-build-rendering" ]]; then
    echo "Deleting Secret Manager secrets..."
    gcloud config set project $PROD_PROJECT
    gcloud secrets delete github-username --quiet
    gcloud secrets delete github-email --quiet
    gcloud secrets delete github-token --quiet

    echo "Deleting foo repos from GitHub..."
    curl \
      -X DELETE \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Authorization: token ${GITHUB_TOKEN}" \
       "https://api.github.com/repos/$GITHUB_USERNAME/foo-config-source"

    curl \
      -X DELETE \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Authorization: token ${GITHUB_TOKEN}" \
       "https://api.github.com/repos/$GITHUB_USERNAME/foo-config-prod"

    curl \
      -X DELETE \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Authorization: token ${GITHUB_TOKEN}" \
       "https://api.github.com/repos/$GITHUB_USERNAME/foo-config-dev"

    echo "Removing local files..."
    rm -r dev-key.json
    rm -r prod-key.json
    rm -rf foo-config-source/
    rm -rf foo-config-dev/
    rm -rf foo-config-prod/
fi

# [END anthosconfig_multi_environments_kustomize_cleanup]