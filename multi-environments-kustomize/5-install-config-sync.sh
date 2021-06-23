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

if [[ -z "$GITHUB_USERNAME" ]]; then
    echo "Must provide GITHUB_USERNAME in environment" 1>&2
    exit 1
fi

export DEV_CTX="gke_${DEV_PROJECT}_${DEV_CLUSTER_ZONE}_dev"
export PROD_CTX="gke_${PROD_PROJECT}_${PROD_CLUSTER_ZONE}_prod"

echo "😺 Populating configmangement.yaml with your Github repo info..." 
sed -i "s/GITHUB_USERNAME/$GITHUB_USERNAME/g" install-config/config-management-dev.yaml
sed -i "s/GITHUB_USERNAME/$GITHUB_USERNAME/g" install-config/config-management-prod.yaml

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