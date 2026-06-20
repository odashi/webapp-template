# Deployment Guide

## Prerequisites

- [gcloud CLI](https://cloud.google.com/sdk/docs/install) (authenticated)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.9
- [Node.js](https://nodejs.org/) >= 20
- A Google Cloud project with billing enabled
- A GitHub repository for this codebase

---

## Step 1: Configure the template

Edit `infra/_locals.tf` and replace all placeholder values:

```hcl
project = {
  id     = "your-gcp-project-id"
  number = "123456789012"   # found in GCP console > Project settings
}

github_repository = {
  owner = "your-github-username"
  name  = "your-repo-name"
}

domains = {
  frontend = "app.yourdomain.com"
  backend  = "api.yourdomain.com"
}
```

Edit `infra/main.tf` and update the GCS backend bucket name:

```hcl
backend "gcs" {
  bucket = "your-gcp-project-id-terraform"
}
```

Edit `frontend/envs/.env.production` to set the production API URL:

```
VITE_API_URL=https://api.yourdomain.com
```

---

## Step 2: Bootstrap (one-time manual setup)

These steps must be done manually before Terraform can manage itself.

### 2-1. Enable required APIs

```bash
gcloud config set project YOUR_PROJECT_ID

gcloud services enable \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  run.googleapis.com
```

### 2-2. Create the GCS bucket for Terraform state

```bash
gcloud storage buckets create gs://YOUR_PROJECT_ID-terraform \
  --location=ASIA-NORTHEAST1 \
  --uniform-bucket-level-access
```

### 2-3. Create the Terraform service account

```bash
gcloud iam service-accounts create terraform \
  --display-name="Terraform service account"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/owner"
```

### 2-4. Connect GitHub to Cloud Build

1. Open [Cloud Build > Repositories](https://console.cloud.google.com/cloud-build/repositories) in the GCP console.
2. Click **Connect repository**, select **GitHub**, and authorize.
3. Select your repository and complete the connection.

---

## Step 3: Run Terraform (first time)

```bash
cd infra
terraform init
terraform apply
```

This creates:
- Artifact Registry repository for Docker images
- Cloud Build triggers (backend deploy, frontend deploy, terraform plan/apply)
- IAM service accounts and permissions for builders and runners
- GCS bucket ownership transferred to Terraform state

---

## Step 4: Generate the frontend lock file

```bash
cd frontend
npm install
```

Commit `package-lock.json` so Docker builds can use `npm ci`:

```bash
git add frontend/package-lock.json
git commit -m "Add frontend package-lock.json"
```

---

## Step 5: First deployment

Push to `main` to trigger Cloud Build:

```bash
git push origin main
```

Cloud Build will:
1. Build and push the backend Docker image to Artifact Registry
2. Deploy the backend to Cloud Run
3. Build and push the frontend Docker image
4. Deploy the frontend to Cloud Run

You can monitor builds at [Cloud Build > History](https://console.cloud.google.com/cloud-build/builds).

---

## Step 6: Domain mapping and DNS

After the first deployment, run Terraform again to apply domain mappings:

```bash
cd infra
terraform apply
```

Terraform will output DNS records for the domain mappings. Add these records to your DNS provider:

1. Go to [Cloud Run > Manage Custom Domains](https://console.cloud.google.com/run/domains) to find the required DNS records.
2. Add the records to your DNS provider.
3. Wait for DNS propagation (up to 24 hours).

---

## Local development

### Backend

Install [uv](https://docs.astral.sh/uv/getting-started/installation/) if not already available.

```bash
cd backend
uv sync
uv run python src/main.py
```

Server runs at `http://localhost:8080`.

### Frontend

```bash
cd frontend
npm install
npm run dev
```

App runs at `http://localhost:5173`. API calls go to `http://localhost:8080`.

---

## Ongoing deployments

After the initial setup, all deployments are automatic:

| Trigger | Action |
|---------|--------|
| Push to `main` (backend files changed) | Build and deploy backend |
| Push to `main` (frontend files changed) | Build and deploy frontend |
| PR targeting `main` (infra files changed) | `terraform plan` |
| Push to `main` (infra files changed) | `terraform apply` |
