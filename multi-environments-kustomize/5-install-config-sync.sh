# !/bin/bash
# https://cloud.google.com/anthos-config-management/docs/how-to/installing 
# https://cloud.google.com/kubernetes-engine/docs/add-on/config-sync/how-to/unstructured-repo 

if [[ -z "$DEV_PROJECT" ]]; then
    echo "Must provide DEV_PROJECT in environment" 1>&2
    exit 1
fi

if [[ -z "$PROD_PROJECT" ]]; then
    echo "Must provide PROD_PROJECT in environment" 1>&2
    exit 1
fi


# echo "Downloading the ConfigSync operator..."
# gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml config-management-operator.yaml

echo "🔁 Installing ConfigSync on the dev cluster..."
gcloud config set project $DEV_PROJECT
kubectx dev 
gcloud alpha container hub config-management apply \
    --membership=dev \
    --config="install-config/config-management-dev.yaml" \
    --project=${DEV_PROJECT}
# kubectl apply -f config-management-operator.yaml 
# kubectl apply -f install-config/config-management-dev.yaml

echo "🔁 Installing ConfigSync on the prod cluster..."
gcloud config set project $PROD_PROJECT
kubectx prod 
# kubectl apply -f config-management-operator.yaml 
# kubectl apply -f install-config/config-management-prod.yaml
gcloud alpha container hub config-management apply \
    --membership=prod \
    --config="install-config/config-management-prod.yaml" \
    --project=${PROD_PROJECT}