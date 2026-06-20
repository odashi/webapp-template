---
allowed-tools: Bash(gcloud:*), Bash(terraform:*), Bash(git:*), Bash(gh:*), Bash(npm:*), Bash(find:*), Bash(grep:*), Bash(ls:*), Read, Edit
description: Interactive wizard to deploy this webapp template to GCP with dev and prod environments and CI/CD
---

# Deployment Wizard

You are an interactive deployment wizard for this webapp template. Guide the user through deploying two environments on Google Cloud Platform:

- **dev** — deployed from the `main` branch (trunk)
- **prod** — deployed from the `release` branch

Trunk-based development model: developers commit to `main`. When the team is ready to release, `main` is merged into `release`, which triggers the prod deployment automatically.

Follow these phases in order. **Do not skip phases.** Summarize what was done at the end of each phase and confirm with the user before moving to the next.

---

## Phase 1: Gather all configuration

Tell the user you need the following values to configure both environments. Ask for all at once:

1. **GCP Project ID** — the project ID string (e.g. `my-project-123`). Must already exist with billing enabled.
2. **GCP Project Number** — the 12-digit number from GCP Console > Project settings.
3. **GitHub repository owner** — GitHub username or organization.
4. **GitHub repository name** — the repo to create or use.
5. **Dev frontend domain** — custom domain for the dev frontend (e.g. `dev.example.com`).
6. **Dev backend domain** — custom domain for the dev API (e.g. `api-dev.example.com`).
7. **Prod frontend domain** — custom domain for the prod frontend (e.g. `app.example.com`).
8. **Prod backend domain** — custom domain for the prod API (e.g. `api.example.com`).

Store all eight values. Do not proceed until all are provided.

---

## Phase 2: Fill in configuration placeholders

Edit `infra/_locals.tf` to replace all placeholder values:

- `my-project-id` → GCP Project ID
- `000000000000` → GCP Project Number
- `my-github-owner` → GitHub owner
- `my-repo-name` → GitHub repo name
- `dev.example.com` → dev frontend domain
- `api-dev.example.com` → dev backend domain
- `app.example.com` → prod frontend domain
- `api.example.com` → prod backend domain

Edit `infra/main.tf` to replace the GCS backend bucket name:

- `my-project-id-terraform` → `{project_id}-terraform`

Show the user a brief summary of every change made. Ask them to confirm before proceeding.

---

## Phase 3: Bootstrap — GCP prerequisites

Run each command, check for errors, and report the result.

### 3-1. Set active project

```bash
gcloud config set project PROJECT_ID
```

### 3-2. Enable required APIs

```bash
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  run.googleapis.com
```

Wait for completion.

### 3-3. Create Terraform state bucket

Check first:

```bash
gcloud storage buckets describe gs://PROJECT_ID-terraform 2>&1
```

If not found:

```bash
gcloud storage buckets create gs://PROJECT_ID-terraform \
  --location=ASIA-NORTHEAST1 \
  --uniform-bucket-level-access
```

### 3-4. Create Terraform service account

Check first:

```bash
gcloud iam service-accounts describe terraform@PROJECT_ID.iam.gserviceaccount.com 2>&1
```

If not found:

```bash
gcloud iam service-accounts create terraform \
  --display-name="Terraform service account"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:terraform@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/owner"
```

### 3-5. Grant Cloud Build impersonation right

This lets Cloud Build runners act as the Terraform SA:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  terraform@PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:PROJECT_NUMBER@cloudbuild.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"
```

Confirm with the user before proceeding.

---

## Phase 4: Initialize git repository and create GitHub repo

### 4-1. Check git state

```bash
git -C . rev-parse --is-inside-work-tree 2>/dev/null && echo "git_exists" || echo "no_git"
```

If `no_git`:

```bash
git init
git checkout -b main
```

### 4-2. Create GitHub repository

Check first:

```bash
gh repo view OWNER/REPO_NAME --json name 2>&1
```

If not found, ask the user whether they want a private or public repository (default: private), then create it:

```bash
gh repo create OWNER/REPO_NAME --private
```

Set the remote:

```bash
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/OWNER/REPO_NAME.git
```

---

## Phase 5: Connect GitHub to Cloud Build (manual step)

The GitHub repository must exist (Phase 4) before connecting it.

Tell the user:

> Cloud Build needs access to your GitHub repository. Please do the following:
>
> 1. Open in your browser:
>    `https://console.cloud.google.com/cloud-build/repositories/2nd-gen?project=PROJECT_ID`
> 2. Click **Connect repository**.
> 3. Select **GitHub** and authorize access to your account if prompted.
> 4. Find and select **OWNER/REPO_NAME**.
> 5. Complete the connection wizard.
>
> Let me know when done.

Wait for the user to confirm.

---

## Phase 6: Generate frontend package lock file

Required for Docker's `npm ci`:

```bash
cd frontend && npm install
```

---

## Phase 7: Run Terraform

### 7-1. Initialize

```bash
cd infra && terraform init
```

### 7-2. Import bootstrap resources

The GCS bucket and Terraform SA were created manually but are also declared in Terraform code. Import them to avoid conflicts:

```bash
cd infra && terraform import \
  module.terraform.google_storage_bucket.terraform \
  PROJECT_ID-terraform
```

```bash
cd infra && terraform import \
  module.terraform.google_service_account.terraform \
  projects/PROJECT_ID/serviceAccounts/terraform@PROJECT_ID.iam.gserviceaccount.com
```

If an import fails because the resource was already imported (e.g. on a retry), that is fine — continue.

### 7-3. Plan and apply

```bash
cd infra && terraform plan
```

Show the user what will be created. Ask for confirmation, then:

```bash
cd infra && terraform apply -auto-approve
```

Wait for completion. Report any errors.

---

## Phase 8: Push to `main` — deploy dev environment

Commit everything and push to `main`. The Cloud Build triggers for `backend-dev` and `frontend-dev` will fire.

```bash
git add infra/_locals.tf infra/main.tf frontend/package-lock.json
git add -A
git status
```

Review staged files with the user, then commit and push:

```bash
git commit -m "Initial deployment configuration"
git push -u origin main
```

Tell the user:

> The code is now on GitHub. Cloud Build is building and deploying the **dev** environment.
>
> Monitor progress at:
> `https://console.cloud.google.com/cloud-build/builds?project=PROJECT_ID`
>
> Two builds will run in parallel:
> - `backend-dev-deploy` → deploys `backend-dev-app` to Cloud Run
> - `frontend-dev-deploy` → deploys `frontend-dev-app` to Cloud Run
>
> This typically takes 5–10 minutes.

Ask the user to monitor and confirm when both builds succeed before proceeding.

---

## Phase 9: Apply dev domain mappings

With dev Cloud Run services now deployed, run Terraform to create the dev domain mappings:

```bash
cd infra && terraform apply \
  -target=module.backend_dev \
  -target=module.frontend_dev \
  -auto-approve
```

After apply, tell the user:

> Add these DNS records at your DNS provider:
>
> 1. Open: `https://console.cloud.google.com/run/domains?project=PROJECT_ID`
> 2. Note the DNS records shown for **DEV_FRONTEND_DOMAIN** and **DEV_BACKEND_DOMAIN**.
> 3. Add them at your DNS provider (A or CNAME record for each).
> 4. DNS propagation typically completes within an hour.

---

## Phase 10: Verify dev environment

Check that dev services are running:

```bash
gcloud run services list --region=asia-northeast1 --project=PROJECT_ID
```

Confirm `backend-dev-app` and `frontend-dev-app` are listed with status `READY`.

Ask the user to open the dev frontend URL in their browser and confirm it loads correctly. The backend health check at `https://DEV_BACKEND_DOMAIN/health` should return `{"status":"ok"}`.

Once the user confirms dev is working, proceed to set up prod.

---

## Phase 11: Push to `release` — deploy prod environment

Create the `release` branch from `main` and push it. This triggers the Cloud Build builds for `backend-prod` and `frontend-prod`.

```bash
git checkout -b release
git push -u origin release
git checkout main
```

Tell the user:

> The `release` branch is now on GitHub. Cloud Build is deploying the **prod** environment.
>
> Two builds will run:
> - `backend-prod-deploy` → deploys `backend-prod-app` to Cloud Run
> - `frontend-prod-deploy` → deploys `frontend-prod-app` to Cloud Run
>
> Monitor at:
> `https://console.cloud.google.com/cloud-build/builds?project=PROJECT_ID`

Ask the user to confirm when both prod builds succeed.

---

## Phase 12: Apply prod domain mappings

With prod Cloud Run services now deployed, apply the remaining domain mappings:

```bash
cd infra && terraform apply -auto-approve
```

After apply, tell the user:

> Add DNS records for the prod domains:
>
> 1. Open: `https://console.cloud.google.com/run/domains?project=PROJECT_ID`
> 2. Note the DNS records for **PROD_FRONTEND_DOMAIN** and **PROD_BACKEND_DOMAIN**.
> 3. Add them at your DNS provider.

---

## Phase 13: Verify prod environment and summarize

Check prod services:

```bash
gcloud run services list --region=asia-northeast1 --project=PROJECT_ID
```

Confirm `backend-prod-app` and `frontend-prod-app` are `READY`.

Ask the user to verify the prod frontend URL and `https://PROD_BACKEND_DOMAIN/health`.

Check all Cloud Build triggers exist:

```bash
gcloud builds triggers list --project=PROJECT_ID
```

Summarize the completed deployment for the user:

- **Dev environment**: DEV_FRONTEND_DOMAIN (deploys on push to `main`)
- **Prod environment**: PROD_FRONTEND_DOMAIN (deploys on push to `release`)
- **How to release**: merge `main` into `release` and push — prod deploys automatically
- **Monitor builds**: `https://console.cloud.google.com/cloud-build/builds?project=PROJECT_ID`
- **Terraform changes**: push to `main` with infra changes triggers `terraform plan`; push to `release` triggers `terraform apply` (wait for plan PR first)

Wait, correct the terraform trigger behavior: review `infra/modules/terraform/builds.tf`. The `terraform plan` trigger fires on PRs targeting `main`, and `terraform apply` fires on push to `main`. Clarify this in the summary.

---

## Error handling

- `gcloud` permission error → remind user to run `gcloud auth login` and verify project permissions.
- `terraform apply` failure → show the full error and suggest fixes before retrying.
- Cloud Build failure → link to the build log URL for diagnosis.
- Resource already exists (bucket, SA) → skip creation, note it was already done.
- Import already in state → skip import, continue.
