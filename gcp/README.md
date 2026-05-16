# ApexRun GCP Deployment Runbook

This directory contains the first-pass GCP deployment path for ApexRun.

## Target Architecture

- `apexrun-api`: Go/Gin API on Cloud Run.
- `apexrun-ml`: FastAPI ML service on Cloud Run.
- `apexrun.app`: static website from `website/` on Firebase Hosting.
- Artifact Registry stores container images.
- Secret Manager stores runtime secrets.
- Supabase remains the system of record for Auth, Postgres, and Edge Functions.

## One-Time GCP Setup

Set local variables:

```powershell
$PROJECT_ID = "apex-run-c8fb9"
$REGION = "us-central1"
$REPOSITORY = "apexrun"
gcloud config set project $PROJECT_ID
```

Enable APIs:

```powershell
gcloud services enable `
  artifactregistry.googleapis.com `
  cloudbuild.googleapis.com `
  run.googleapis.com `
  secretmanager.googleapis.com `
  firebase.googleapis.com `
  firebasehosting.googleapis.com
```

Create the Artifact Registry repository:

```powershell
gcloud artifacts repositories create $REPOSITORY `
  --repository-format=docker `
  --location=$REGION `
  --description="ApexRun container images"
```

Create the Cloud Run runtime service account:

```powershell
gcloud iam service-accounts create apexrun-runtime `
  --display-name="ApexRun Cloud Run Runtime"
```

Grant Secret Manager access to the runtime service account:

```powershell
gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:apexrun-runtime@$PROJECT_ID.iam.gserviceaccount.com" `
  --role="roles/secretmanager.secretAccessor"
```

Grant Cloud Build permission to deploy Cloud Run revisions and use the runtime service account:

```powershell
$PROJECT_NUMBER = gcloud projects describe $PROJECT_ID --format="value(projectNumber)"
$CLOUD_BUILD_SA = "$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:$CLOUD_BUILD_SA" `
  --role="roles/run.admin"

gcloud iam service-accounts add-iam-policy-binding `
  "apexrun-runtime@$PROJECT_ID.iam.gserviceaccount.com" `
  --member="serviceAccount:$CLOUD_BUILD_SA" `
  --role="roles/iam.serviceAccountUser"
```

## Required Secrets

Create these Secret Manager secrets before running Cloud Build:

```powershell
gcloud secrets create apexrun-database-url --replication-policy=automatic
gcloud secrets create apexrun-supabase-url --replication-policy=automatic
gcloud secrets create apexrun-supabase-anon-key --replication-policy=automatic
gcloud secrets create apexrun-supabase-jwt-secret --replication-policy=automatic
gcloud secrets create apexrun-redis-url --replication-policy=automatic
gcloud secrets create apexrun-redis-password --replication-policy=automatic
```

Add secret versions:

```powershell
"postgresql://..." | gcloud secrets versions add apexrun-database-url --data-file=-
"https://<project>.supabase.co" | gcloud secrets versions add apexrun-supabase-url --data-file=-
"<supabase-anon-key>" | gcloud secrets versions add apexrun-supabase-anon-key --data-file=-
"<supabase-jwt-secret>" | gcloud secrets versions add apexrun-supabase-jwt-secret --data-file=-
"redis://..." | gcloud secrets versions add apexrun-redis-url --data-file=-
"<redis-password>" | gcloud secrets versions add apexrun-redis-password --data-file=-
```

## Deploy Containers

From the repo root:

```powershell
gcloud builds submit --config gcp/cloudbuild.yaml `
  --substitutions=_REGION=$REGION,_REPOSITORY=$REPOSITORY
```

After deployment, capture service URLs:

```powershell
gcloud run services describe apexrun-api --region=$REGION --format="value(status.url)"
gcloud run services describe apexrun-ml --region=$REGION --format="value(status.url)"
```

Use those URLs in Flutter release builds:

```powershell
flutter build appbundle --release `
  --dart-define-from-file=.env.json `
  --dart-define=BACKEND_API_URL=https://<apexrun-api-url> `
  --dart-define=ML_SERVICE_URL=https://<apexrun-ml-url>
```

## Deploy Website

`firebase.json` serves the `website/` directory and rewrites:

- `/privacy` -> `/privacy.html`
- `/terms` -> `/terms.html`
- `/support` -> `/support.html`
- `/account/delete` -> `/account/delete.html`

Deploy:

```powershell
firebase deploy --only hosting
```

Before production DNS cutover, replace placeholders in:

- `website/.well-known/apple-app-site-association`
- `website/.well-known/assetlinks.json`

## Smoke Checks

```powershell
$API_URL = gcloud run services describe apexrun-api --region=$REGION --format="value(status.url)"
$ML_URL = gcloud run services describe apexrun-ml --region=$REGION --format="value(status.url)"

Invoke-WebRequest "$API_URL/health"
Invoke-WebRequest "$ML_URL/health"
Invoke-WebRequest "$ML_URL/ready"
Invoke-WebRequest "https://apexrun.app/privacy"
Invoke-WebRequest "https://apexrun.app/.well-known/assetlinks.json"
```

## Known Follow-Ups

- Put the ML service behind authenticated backend calls if abuse becomes a concern.
- Add Cloud Run liveness/readiness probe flags after the first successful deploy.
- Add Sentry release/env tags to both Cloud Run services.
- Replace synthetic model training with a consented dataset and offline evaluation report before making strong injury prediction claims.
