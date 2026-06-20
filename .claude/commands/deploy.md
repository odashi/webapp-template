---
allowed-tools: Bash(gcloud:*), Bash(terraform:*), Bash(git:*), Bash(gh:*), Bash(npm:*), Bash(find:*), Bash(grep:*), Bash(ls:*), Read, Edit
description: Interactive wizard to deploy this webapp template to GCP with separate dev and prod projects and CI/CD
---

# Deployment Wizard

You are an interactive deployment wizard for this webapp template. Guide the user through deploying two fully isolated environments on Google Cloud Platform:

- **dev** — its own GCP project, deployed from the `main` branch (trunk)
- **prod** — its own GCP project, deployed from the `release` branch

Each project has independent Cloud Build triggers, Cloud Run services, Artifact Registry, IAM, and Terraform state. Changes in one project cannot affect the other.

Trunk-based development model: developers commit to `main` (deploys to dev automatically). When ready to release, `main` is merged into `release`, which triggers the prod deployment.

Follow these phases in order. **Do not skip phases.** Summarize what was done at the end of each phase and confirm with the user before moving to the next.

---

## Phase 1: Read configuration from deploy.config.json

Read `deploy.config.json` at the repository root.

If the file does not exist, tell the user:

> `deploy.config.json` が見つかりません。リポジトリルートに作成してください。
> テンプレートは `deploy.config.json` の形式を参照してください。

If the file exists, read it and validate that **none of the following placeholder values remain**:

- `my-dev-project-id`
- `my-prod-project-id`
- `000000000000`
- `my-github-owner`
- `my-repo-name`
- `dev.example.com`
- `api-dev.example.com`
- `app.example.com`
- `api.example.com`

If any placeholder remains, show the user which fields still need to be filled and tell them:

> `deploy.config.json` を編集してすべての項目を実際の値に置き換えてから、再度ウィザードを起動してください。

Do not proceed until the file is valid. If the user says they have updated it, re-read and re-validate.

Once valid, extract and store the following variables for use throughout the wizard:

- `DEV_PROJECT_ID` = `.dev.project_id`
- `DEV_PROJECT_NUMBER` = `.dev.project_number`
- `PROD_PROJECT_ID` = `.prod.project_id`
- `PROD_PROJECT_NUMBER` = `.prod.project_number`
- `GITHUB_OWNER` = `.github.owner`
- `GITHUB_REPO` = `.github.name`
- `DEV_FRONTEND_DOMAIN` = `.domains.dev.frontend`
- `DEV_BACKEND_DOMAIN` = `.domains.dev.backend`
- `PROD_FRONTEND_DOMAIN` = `.domains.prod.frontend`
- `PROD_BACKEND_DOMAIN` = `.domains.prod.backend`

Show the user the values that were read and confirm before proceeding.

---

## Phase 1b: Ensure working on init-config branch

`init-config` is a **local-only** branch used to keep deployment configuration separate from template improvements. It is never pushed to remote independently.

Check the current branch:

```bash
git branch --show-current
```

- If already on `init-config`: continue.
- If `init-config` exists locally but is not checked out: `git checkout init-config`
- If `init-config` does not exist yet: `git checkout -b init-config`

Tell the user:

> 設定ファイルへの変更は `init-config` ブランチで進めます。デプロイ準備が整ったら `main` にマージして push します。`init-config` 自体は remote には push しません。

### If a template improvement is needed during the wizard

When the user requests a fix to the wizard or template files (not deployment config):

1. Commit any pending `init-config` changes: `git add -A && git commit -m "..."` (if any)
2. `git checkout main`
3. Apply the fix, commit, and push to remote
4. `git checkout init-config`
5. `git merge main` to bring the fix into `init-config`
6. Resume the wizard

---

## Phase 2: Fill in configuration placeholders

Using the values read from `deploy.config.json`, edit the Terraform files to replace all placeholders.

Edit `infra/dev/_locals.tf`:
- `my-dev-project-id` → `DEV_PROJECT_ID`
- `000000000000` → `DEV_PROJECT_NUMBER`
- `my-github-owner` → `GITHUB_OWNER`
- `my-repo-name` → `GITHUB_REPO`
- `dev.example.com` → `DEV_FRONTEND_DOMAIN`
- `api-dev.example.com` → `DEV_BACKEND_DOMAIN`

Edit `infra/dev/main.tf`:
- `my-dev-project-id-terraform` → `DEV_PROJECT_ID-terraform`

Edit `infra/prod/_locals.tf`:
- `my-prod-project-id` → `PROD_PROJECT_ID`
- `000000000000` → `PROD_PROJECT_NUMBER`
- `my-github-owner` → `GITHUB_OWNER`
- `my-repo-name` → `GITHUB_REPO`
- `app.example.com` → `PROD_FRONTEND_DOMAIN`
- `api.example.com` → `PROD_BACKEND_DOMAIN`

Edit `infra/prod/main.tf`:
- `my-prod-project-id-terraform` → `PROD_PROJECT_ID-terraform`

After all edits, show the user a brief summary of every file changed. Ask them to confirm before proceeding.

---

## Phase 3: Bootstrap dev GCP project

Run each command, check for errors, and report the result.

### 3-1. Set active project to dev

```bash
gcloud config set project DEV_PROJECT_ID
```

### 3-2. Enable required APIs in dev project

```bash
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  run.googleapis.com \
  --project=DEV_PROJECT_ID
```

### 3-3. Create Terraform state bucket in dev project

```bash
gcloud storage buckets describe gs://DEV_PROJECT_ID-terraform 2>&1
```

If not found:

```bash
gcloud storage buckets create gs://DEV_PROJECT_ID-terraform \
  --project=DEV_PROJECT_ID \
  --location=ASIA-NORTHEAST1 \
  --uniform-bucket-level-access
```

### 3-4. Create Terraform service account in dev project

```bash
gcloud iam service-accounts describe terraform@DEV_PROJECT_ID.iam.gserviceaccount.com \
  --project=DEV_PROJECT_ID 2>&1
```

If not found:

```bash
gcloud iam service-accounts create terraform \
  --display-name="Terraform service account" \
  --project=DEV_PROJECT_ID

gcloud projects add-iam-policy-binding DEV_PROJECT_ID \
  --member="serviceAccount:terraform@DEV_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/owner"
```

### 3-5. Grant Cloud Build impersonation right in dev project

```bash
gcloud iam service-accounts add-iam-policy-binding \
  terraform@DEV_PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:DEV_PROJECT_NUMBER@cloudbuild.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project=DEV_PROJECT_ID
```

Confirm with the user before proceeding.

---

## Phase 4: Bootstrap prod GCP project

Repeat the same steps as Phase 3 for the prod project.

### 4-1. Enable required APIs in prod project

```bash
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  run.googleapis.com \
  --project=PROD_PROJECT_ID
```

### 4-2. Create Terraform state bucket in prod project

```bash
gcloud storage buckets describe gs://PROD_PROJECT_ID-terraform 2>&1
```

If not found:

```bash
gcloud storage buckets create gs://PROD_PROJECT_ID-terraform \
  --project=PROD_PROJECT_ID \
  --location=ASIA-NORTHEAST1 \
  --uniform-bucket-level-access
```

### 4-3. Create Terraform service account in prod project

```bash
gcloud iam service-accounts describe terraform@PROD_PROJECT_ID.iam.gserviceaccount.com \
  --project=PROD_PROJECT_ID 2>&1
```

If not found:

```bash
gcloud iam service-accounts create terraform \
  --display-name="Terraform service account" \
  --project=PROD_PROJECT_ID

gcloud projects add-iam-policy-binding PROD_PROJECT_ID \
  --member="serviceAccount:terraform@PROD_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/owner"
```

### 4-4. Grant Cloud Build impersonation right in prod project

```bash
gcloud iam service-accounts add-iam-policy-binding \
  terraform@PROD_PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:PROD_PROJECT_NUMBER@cloudbuild.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project=PROD_PROJECT_ID
```

Confirm with the user before proceeding.

---

## Phase 5: Verify git repository

```bash
git -C . rev-parse --is-inside-work-tree 2>/dev/null && echo "git_exists" || echo "no_git"
```

If `no_git`, initialize, create `main`, and then create `init-config`:

```bash
git init
git checkout -b main
git checkout -b init-config
```

If git already exists, confirm the current branch is `init-config` (Phase 1b should have handled this).

---

## Phase 6: Connect GitHub to Cloud Build (manual step — both projects)

Tell the user:

> Cloud Build in **both** projects needs access to your GitHub repository. Please complete this for each project:
>
> **Dev project:**
> 1. Open: `https://console.cloud.google.com/cloud-build/repositories/2nd-gen?project=DEV_PROJECT_ID`
> 2. Click **Connect repository** → select **GitHub** → authorize if prompted.
> 3. Find and select **OWNER/REPO_NAME** → complete the wizard.
>
> **Prod project:**
> 1. Open: `https://console.cloud.google.com/cloud-build/repositories/2nd-gen?project=PROD_PROJECT_ID`
> 2. Click **Connect repository** → select **GitHub** → authorize if prompted.
> 3. Find and select **OWNER/REPO_NAME** → complete the wizard.
>
> Let me know when both connections are confirmed.

Wait for the user to confirm both before proceeding.

---

## Phase 7: Generate frontend package lock file

Required for Docker's `npm ci`:

```bash
cd frontend && npm install
```

---

## Phase 8: Run Terraform for dev project

### 8-1. Initialize

```bash
cd infra/dev && terraform init
```

### 8-2. Import bootstrap resources

The GCS bucket and Terraform SA were created manually but are also declared in Terraform code. Import them:

```bash
cd infra/dev && terraform import \
  module.terraform.google_storage_bucket.terraform \
  DEV_PROJECT_ID-terraform
```

```bash
cd infra/dev && terraform import \
  module.terraform.google_service_account.terraform \
  projects/DEV_PROJECT_ID/serviceAccounts/terraform@DEV_PROJECT_ID.iam.gserviceaccount.com
```

If an import fails because the resource was already imported (e.g. on a retry), that is fine — continue.

### 8-3. Plan and apply

```bash
cd infra/dev && terraform plan
```

Show the user a summary of resources to be created. Ask for confirmation, then:

```bash
cd infra/dev && terraform apply -auto-approve
```

Wait for completion. Report any errors.

---

## Phase 9: Run Terraform for prod project

Repeat Phase 8 for the prod project.

### 9-1. Initialize

```bash
cd infra/prod && terraform init
```

### 9-2. Import bootstrap resources

```bash
cd infra/prod && terraform import \
  module.terraform.google_storage_bucket.terraform \
  PROD_PROJECT_ID-terraform
```

```bash
cd infra/prod && terraform import \
  module.terraform.google_service_account.terraform \
  projects/PROD_PROJECT_ID/serviceAccounts/terraform@PROD_PROJECT_ID.iam.gserviceaccount.com
```

### 9-3. Plan and apply

```bash
cd infra/prod && terraform plan
```

Show the user what will be created. Ask for confirmation, then:

```bash
cd infra/prod && terraform apply -auto-approve
```

---

## Phase 10: Merge init-config to main and push — deploy dev environment

All configuration is ready on `init-config`. Now merge it into `main` and push to trigger the dev Cloud Build.

### 10-1. Commit remaining changes on init-config

Make sure all changes are committed on `init-config`:

```bash
git add -A
git status
```

If there are uncommitted changes:

```bash
git commit -m "Initial deployment configuration"
```

### 10-2. Merge into main and push

```bash
git checkout main
git merge --no-ff init-config -m "Merge init-config: initial deployment configuration"
git push origin main
```

Tell the user:

> `main` を push しました。Cloud Build が **dev プロジェクト** にデプロイを開始します。
>
> Monitor at: `https://console.cloud.google.com/cloud-build/builds?project=DEV_PROJECT_ID`
>
> Two builds will run:
> - `backend-deploy` → deploys `backend-app` to Cloud Run (dev)
> - `frontend-deploy` → deploys `frontend-app` to Cloud Run (dev)
>
> This typically takes 5–10 minutes.

Ask the user to confirm when both dev builds succeed before proceeding.

---

## Phase 11: Apply dev domain mappings

```bash
cd infra/dev && terraform apply -auto-approve
```

After apply, tell the user:

> Add DNS records for the dev domains:
>
> 1. Open: `https://console.cloud.google.com/run/domains?project=DEV_PROJECT_ID`
> 2. Note the DNS records for **DEV_FRONTEND_DOMAIN** and **DEV_BACKEND_DOMAIN**.
> 3. Add them at your DNS provider. Propagation typically completes within an hour.

---

## Phase 12: Verify dev environment

```bash
gcloud run services list --region=asia-northeast1 --project=DEV_PROJECT_ID
```

Confirm `backend-app` and `frontend-app` are `READY`.

Ask the user to open the dev frontend URL and confirm it loads. The backend health check at `https://DEV_BACKEND_DOMAIN/health` should return `{"status":"ok"}`.

Once the user confirms dev is working, proceed to deploy prod.

---

## Phase 13: Push to `release` — deploy prod environment

Create the `release` branch from `main` and push it. Cloud Build in the prod project will fire.

```bash
git checkout -b release
git push -u origin release
git checkout main
```

Tell the user:

> The `release` branch is on GitHub. Cloud Build in the **prod project** is deploying.
>
> Monitor at: `https://console.cloud.google.com/cloud-build/builds?project=PROD_PROJECT_ID`
>
> Two builds will run:
> - `backend-deploy` → deploys `backend-app` to Cloud Run (prod)
> - `frontend-deploy` → deploys `frontend-app` to Cloud Run (prod)

Ask the user to confirm when both prod builds succeed.

---

## Phase 14: Apply prod domain mappings

```bash
cd infra/prod && terraform apply -auto-approve
```

After apply, tell the user:

> Add DNS records for the prod domains:
>
> 1. Open: `https://console.cloud.google.com/run/domains?project=PROD_PROJECT_ID`
> 2. Note the DNS records for **PROD_FRONTEND_DOMAIN** and **PROD_BACKEND_DOMAIN**.
> 3. Add them at your DNS provider.

---

## Phase 15: Verify prod environment and summarize

```bash
gcloud run services list --region=asia-northeast1 --project=PROD_PROJECT_ID
```

Confirm `backend-app` and `frontend-app` are `READY`.

Check Cloud Build triggers in both projects:

```bash
gcloud builds triggers list --project=DEV_PROJECT_ID
gcloud builds triggers list --project=PROD_PROJECT_ID
```

Summarize the completed deployment:

- **Dev environment**: DEV_FRONTEND_DOMAIN
  - Deploys automatically on push to `main` (dev project)
  - Terraform CI: plan on PR to `main`, apply on push to `main`
- **Prod environment**: PROD_FRONTEND_DOMAIN
  - Deploys automatically on push to `release` (prod project)
  - Terraform CI: plan on PR to `release`, apply on push to `release`
- **How to release**: merge `main` into `release` and push → prod deploys automatically
- **Monitor dev builds**: `https://console.cloud.google.com/cloud-build/builds?project=DEV_PROJECT_ID`
- **Monitor prod builds**: `https://console.cloud.google.com/cloud-build/builds?project=PROD_PROJECT_ID`

---

## Error handling

- `gcloud` permission error → remind user to run `gcloud auth login` and verify project permissions.
- `terraform apply` failure → show the full error and suggest fixes before retrying.
- Cloud Build failure → link to the build log URL for diagnosis.
- Resource already exists (bucket, SA) → skip creation, note it was already done.
- Import already in state → skip import, continue.
