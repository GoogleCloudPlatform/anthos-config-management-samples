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

echo "⏬ Setting up local kubectx..."
gcloud container clusters get-credentials dev --zone ${DEV_CLUSTER_ZONE} --project ${DEV_PROJECT}
kubectx dev=. 

gcloud container clusters get-credentials prod --zone ${PROD_CLUSTER_ZONE} --project ${PROD_PROJECT}
kubectx prod=. 

echo "⭐️ Done creating clusters."