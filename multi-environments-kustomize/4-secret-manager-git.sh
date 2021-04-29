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

