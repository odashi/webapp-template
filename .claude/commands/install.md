---
allowed-tools: Bash(gcloud:*), Bash(terraform:*), Bash(git:*), Bash(gh:*), Bash(npm:*), Bash(find:*), Bash(grep:*), Bash(ls:*), Read, Edit, Write
description: Interactive wizard to deploy this webapp template to GCP with separate dev and prod projects and CI/CD
---

# Installation Wizard

You are an interactive installation wizard for this webapp template. Guide the user through deploying two fully isolated environments on Google Cloud Platform:

- **dev** — its own GCP project, deployed from the `main` branch (trunk)
- **prod** — its own GCP project, deployed from the `release` branch

Each project has independent Cloud Build triggers, Cloud Run services, Artifact Registry, IAM, and Terraform state. Changes in one project cannot affect the other.

Trunk-based development model: developers commit to `main` (deploys to dev automatically). When ready to release, `main` is merged into `release`, which triggers the prod deployment.

Follow these phases in order. **Do not skip phases.** Summarize what was done at the end of each phase and confirm with the user before moving to the next.

---

## Phase 0: Set communication language

Ask the user:

> What language would you like to use during this wizard? (e.g., English, 日本語, etc.)

After the user replies, write (or append) the following to `CLAUDE.md` at the repository root:

```markdown
## Language

Respond to the user in [CHOSEN_LANGUAGE].
```

Replace `[CHOSEN_LANGUAGE]` with the language the user chose (e.g., `English`, `Japanese`). If `CLAUDE.md` already exists, read it first and append the `## Language` section only if it is not already present; otherwise update the existing value.

From this point forward, communicate with the user in the chosen language.

---

## Phase 0b: Check prerequisite tools

Before doing any work, verify that required tools are installed. Run:

```bash
gcloud --version 2>&1 | head -1
terraform --version 2>&1 | head -1
git --version 2>&1
npm --version 2>&1
gh --version 2>&1 | head -1
```

Required tools (wizard cannot proceed without these):

| Tool | Purpose |
|---|---|
| `gcloud` | Enable GCP APIs, manage Cloud Build triggers |
| `terraform` | Provision GCP infrastructure |
| `git` | Manage branches and push to deployment repo |
| `npm` | Generate `package-lock.json` for frontend Docker build |

Optional tool:

| Tool | Purpose |
|---|---|
| `gh` | Create the GitHub deployment repository automatically |

If any **required** tool is missing, tell the user which tools need to be installed and ask them to install the missing tools before continuing. Do not proceed until all required tools are available.

If `gh` is missing, note that the user will need to create the GitHub repository manually in Phase 6.

Once all required tools are present, confirm with the user before proceeding.

---

## Phase 0c: What this wizard will do

Explain to the user what this wizard will do, including all changes it makes to external systems. Say:

> This wizard will set up a complete deployment environment for this webapp. Here is what it will do:
>
> **GitHub changes:**
> - Create a new GitHub repository (`GITHUB_OWNER/GITHUB_REPO`) that will hold your deployment code
> - Push your configured code to that repository
> - Install the Cloud Build GitHub App on that repository (for both GCP projects)
>
> **Google Cloud changes (dev project: `DEV_PROJECT_ID`):**
> - Enable APIs: Artifact Registry, Cloud Build, Cloud Resource Manager, IAM, Cloud Run
> - Create a GCS bucket for Terraform state
> - Create a Terraform service account with the necessary IAM roles
> - Create an Artifact Registry repository for Docker images
> - Create Cloud Build triggers (CI/CD pipelines for backend, frontend, and Terraform)
> - Deploy backend and frontend applications to Cloud Run
> - Create Cloud Run domain mappings for your custom domains
>
> **Google Cloud changes (prod project: `PROD_PROJECT_ID`):**
> - Same as above for the prod project
>
> **Local file changes:**
> - `CLAUDE.md` — language preference (already done in Phase 0)
> - `infra/dev/_locals.tf`, `infra/dev/main.tf` — filled with your dev project values
> - `infra/prod/_locals.tf`, `infra/prod/main.tf` — filled with your prod project values
>
> Note: placeholder values are only filled on the local `init-config` branch. The template repository (`origin`) will keep placeholder values on `main`.
>
> **DNS changes (manual):**
> - You will need to add CNAME records in your DNS provider for your custom domains (shown later in the wizard).
>
> Do you want to proceed?

Wait for the user to confirm before continuing.

---

## Phase 1: Read configuration from deploy.config.json

Read `deploy.config.json` at the repository root.

If the file does not exist, tell the user:

> `deploy.config.json` was not found at the repository root. Please create it using the placeholder values in the existing template as a guide.

If the file exists, read it and validate that **no value in the file contains `[[[`** — any occurrence of `[[[` means that field has not been filled in yet.

Check each field and list any that still contain `[[[`. If any are found, tell the user:

> Please edit `deploy.config.json` and replace all `[[[...]]]` placeholders with your actual values, then run the wizard again.

The fields to fill in are:
- `region.default` — GCP region (e.g. `asia-northeast1`)
- `region.storage` — GCS storage region (e.g. `ASIA-NORTHEAST1`)
- `dev.project_id` — dev GCP project ID
- `dev.project_number` — dev GCP project number (12-digit)
- `prod.project_id` — prod GCP project ID
- `prod.project_number` — prod GCP project number (12-digit)
- `github.owner` — GitHub username or organization
- `github.name` — deployment repository name (will be created in Phase 6)
- `domains.dev.frontend` — dev frontend custom domain
- `domains.dev.backend` — dev backend custom domain
- `domains.prod.frontend` — prod frontend custom domain
- `domains.prod.backend` — prod backend custom domain

Do not proceed until the file is valid. If the user says they have updated it, re-read and re-validate.

Once valid, extract and store the following variables for use throughout the wizard:

- `REGION` = `.region.default`
- `STORAGE_REGION` = `.region.storage`
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

`init-config` is a **local-only** branch used to keep deployment configuration separate from template improvements. It is never pushed to `origin` (the template repo).

Check the current branch:

```bash
git branch --show-current
```

- If already on `init-config`: continue.
- If `init-config` exists locally but is not checked out: `git checkout init-config`
- If `init-config` does not exist yet: `git checkout -b init-config`

Tell the user:

> Configuration changes will be made on the `init-config` branch. This branch is never pushed to the template repository (`origin`) — it is only pushed to the deployment repository (`app`). Template improvements stay on `main`.

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

Using the values read from `deploy.config.json`, edit the Terraform files to replace all `[[[...]]]` placeholders. Each placeholder name matches the JSON path of the corresponding field in `deploy.config.json`.

Edit `infra/dev/_locals.tf`:
- `[[[dev.project_id]]]` → `DEV_PROJECT_ID`
- `[[[dev.project_number]]]` → `DEV_PROJECT_NUMBER`
- `[[[region.default]]]` → `REGION`
- `[[[region.storage]]]` → `STORAGE_REGION`
- `[[[github.owner]]]` → `GITHUB_OWNER`
- `[[[github.name]]]` → `GITHUB_REPO`
- `[[[domains.dev.frontend]]]` → `DEV_FRONTEND_DOMAIN`
- `[[[domains.dev.backend]]]` → `DEV_BACKEND_DOMAIN`

Edit `infra/dev/main.tf`:
- `[[[dev.project_id]]]-terraform` → `DEV_PROJECT_ID-terraform`

Edit `infra/prod/_locals.tf`:
- `[[[prod.project_id]]]` → `PROD_PROJECT_ID`
- `[[[prod.project_number]]]` → `PROD_PROJECT_NUMBER`
- `[[[region.default]]]` → `REGION`
- `[[[region.storage]]]` → `STORAGE_REGION`
- `[[[github.owner]]]` → `GITHUB_OWNER`
- `[[[github.name]]]` → `GITHUB_REPO`
- `[[[domains.prod.frontend]]]` → `PROD_FRONTEND_DOMAIN`
- `[[[domains.prod.backend]]]` → `PROD_BACKEND_DOMAIN`

Edit `infra/prod/main.tf`:
- `[[[prod.project_id]]]-terraform` → `PROD_PROJECT_ID-terraform`

After all edits, show the user a brief summary of every file changed. Ask them to confirm before proceeding.

---

## Phase 3: Bootstrap dev GCP project

Only the Cloud Build API needs to be enabled before Terraform runs. Terraform will create everything else (GCS bucket, Terraform SA, IAM bindings, Cloud Build triggers) in Phase 8.

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

Confirm with the user before proceeding.

---

## Phase 4: Bootstrap prod GCP project

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

## Phase 6: Create deployment repository and push

This phase creates the GitHub deployment repository and pushes the configured code to it. The deployment repository (`app` remote) is separate from the template repository (`origin`) and receives all future deployment pushes. The `origin` remote always retains placeholder values on `main`.

### 6-1. Generate frontend package lock file

Required for Docker's `npm ci` during Cloud Build:

```bash
cd frontend && npm install
```

### 6-2. Commit all changes on init-config

```bash
git add -A
git status
```

If there are uncommitted changes:

```bash
git commit -m "Initial deployment configuration"
```

### 6-3. Create GitHub deployment repository

Check if `gh` CLI is available:

```bash
gh --version 2>&1
```

If available, create the repository (adjust `--private`/`--public` as preferred):

```bash
gh repo create GITHUB_OWNER/GITHUB_REPO --private --description "Web application"
```

If `gh` is not available or the user prefers to create it manually, tell them:

> Please create a new GitHub repository:
> - URL: `https://github.com/new`
> - Owner: **GITHUB_OWNER**
> - Repository name: **GITHUB_REPO**
> - **Do not initialize the repository with a README, .gitignore, or license**
>
> Let me know when it is created.

Wait for the user to confirm the repository exists before continuing.

### 6-4. Add `app` remote

Check if `app` remote already exists:

```bash
git remote get-url app 2>/dev/null && echo "exists" || echo "not_found"
```

If not found:

```bash
git remote add app git@github.com:GITHUB_OWNER/GITHUB_REPO.git
```

### 6-5. Push to deployment repository

Push the `init-config` branch (which contains real configuration values) as `main` to the deployment repository:

```bash
git push app init-config:main
```

This is the only push to the deployment repo `main` branch that originates from `init-config`. From here on, everyday development happens in the deployment repository itself, not the template.

Confirm with the user before proceeding.

---

## Phase 7: Connect GitHub to Cloud Build (manual step — both projects)

The Terraform modules use 1st gen `google_cloudbuild_trigger` resources with a `github` block. These require the **Cloud Build GitHub App** to be installed on the deployment repository in each GCP project.

Tell the user:

> Please connect the Cloud Build GitHub App to the deployment repository in **both GCP projects**.
>
> **Dev project:**
> 1. Open `https://console.cloud.google.com/cloud-build/triggers?project=DEV_PROJECT_ID`
> 2. Click **Connect Repository**
> 3. Select **GitHub (Cloud Build GitHub App)** as the source
> 4. Authenticate with GitHub and select **GITHUB_OWNER/GITHUB_REPO**, then complete the wizard
>
> **Prod project:**
> 1. Open `https://console.cloud.google.com/cloud-build/triggers?project=PROD_PROJECT_ID`
> 2. Click **Connect Repository**
> 3. Select **GitHub (Cloud Build GitHub App)** as the source
> 4. Authenticate with GitHub and select **GITHUB_OWNER/GITHUB_REPO**, then complete the wizard
>
> Note: use the **Triggers** page (1st gen), not the Repositories page (2nd gen). The "Connect Repository" button is only available on the Triggers page.
>
> If the GitHub App is already installed for your GitHub account from a previous project, step 4 may skip the authorization dialog and go directly to repository selection.
>
> Let me know when both connections are complete.

Wait for the user to confirm both before proceeding.

---

## Phase 8: Run Terraform for dev project

The GCS backend is initially commented out in `infra/dev/main.tf`. This allows the first apply to run with local state and create the GCS bucket, after which state is migrated to GCS.

### 8-1. Initialize (local state)

```bash
cd infra/dev && terraform init
```

### 8-2. Plan and apply

```bash
cd infra/dev && terraform plan
```

Show the user a summary of resources to be created (GCS bucket, Terraform SA, IAM bindings, Cloud Build triggers, Artifact Registry). Ask for confirmation, then:

```bash
cd infra/dev && terraform apply -auto-approve
```

Wait for completion. Report any errors.

### 8-3. Uncomment GCS backend and migrate state

Edit `infra/dev/main.tf` to uncomment the `backend "gcs"` block:

```hcl
  backend "gcs" {
    bucket = "DEV_PROJECT_ID-terraform"
  }
```

Then re-initialize to migrate local state to GCS:

```bash
cd infra/dev && terraform init -migrate-state
```

Answer `yes` when prompted to copy the existing state to the new backend.

### 8-4. Commit lock file

```bash
git add infra/dev/.terraform.lock.hcl infra/dev/main.tf
git commit -m "Enable GCS backend for dev Terraform state"
```

---

## Phase 9: Run Terraform for prod project

### 9-1. Initialize (local state)

```bash
cd infra/prod && terraform init
```

### 9-2. Plan and apply

```bash
cd infra/prod && terraform plan
```

Show what will be created. Ask for confirmation, then:

```bash
cd infra/prod && terraform apply -auto-approve
```

### 9-3. Uncomment GCS backend and migrate state

Edit `infra/prod/main.tf` to uncomment the `backend "gcs"` block:

```hcl
  backend "gcs" {
    bucket = "PROD_PROJECT_ID-terraform"
  }
```

Then re-initialize:

```bash
cd infra/prod && terraform init -migrate-state
```

### 9-4. Commit lock file and push to deployment repo

```bash
git add infra/prod/.terraform.lock.hcl infra/prod/main.tf
git commit -m "Enable GCS backend for prod Terraform state"
git push app init-config:main
```

This push will trigger the dev Terraform CI (no-op since state is up to date).

---

## Phase 10: Trigger initial dev deployment

Terraform created the Cloud Build triggers in the dev project. Because the push to `main` happened in Phase 6 — before the triggers existed — the push did not fire any builds. Run the service triggers manually for the first deployment.

List triggers to find their exact names:

```bash
gcloud builds triggers list --project=DEV_PROJECT_ID --format="table(name)"
```

Run both service deploy triggers against the `main` branch:

```bash
gcloud builds triggers run backend-deploy --branch=main --project=DEV_PROJECT_ID
gcloud builds triggers run frontend-deploy --branch=main --project=DEV_PROJECT_ID
```

If the trigger names differ from `backend-deploy` / `frontend-deploy`, use the actual names shown above.

Tell the user:

> Dev builds have started.
>
> Build status: `https://console.cloud.google.com/cloud-build/builds?project=DEV_PROJECT_ID`
>
> Two builds are running:
> - `backend-deploy` → deploys `backend-app` to Cloud Run
> - `frontend-deploy` → deploys `frontend-app` to Cloud Run
>
> These typically take 5–10 minutes. Let me know when both succeed.

Wait for the user to confirm both dev builds succeed before proceeding.

Note: Going forward, pushes to `main` that include changes under `backend/**/*` or `frontend/**/*` will auto-trigger the respective service build. Pushes that only change Terraform files (`infra/**/*`) will trigger only the `terraform-apply` trigger.

---

## Phase 11: Apply dev domain mappings

Cloud Run services are now deployed. Enable domain mappings by editing `infra/dev/_locals.tf`:

Change:
```hcl
  enable_domain_mapping = false
```
to:
```hcl
  enable_domain_mapping = true
```

Then apply:

```bash
cd infra/dev && terraform apply -auto-approve
```

Commit and push to the deployment repo so the state is reflected:

```bash
git add infra/dev/_locals.tf
git commit -m "Enable dev domain mappings"
git push app init-config:main
```

After apply, tell the user:

> Please add the following DNS records for the dev domains. All Cloud Run custom domains use a CNAME pointing to `ghs.googlehosted.com.`:
>
> | Domain | Type | Value |
> |---|---|---|
> | **DEV_FRONTEND_DOMAIN** | CNAME | `ghs.googlehosted.com.` |
> | **DEV_BACKEND_DOMAIN** | CNAME | `ghs.googlehosted.com.` |
>
> Add these CNAME records in your DNS provider. Propagation may take up to 1 hour.
> You can monitor SSL certificate issuance at: `https://console.cloud.google.com/run/domains?project=DEV_PROJECT_ID`

---

## Phase 12: Verify dev environment

```bash
gcloud run services list --region=REGION --project=DEV_PROJECT_ID
```

Confirm `backend-app` and `frontend-app` are `READY`.

Ask the user to open the dev frontend URL and confirm it loads. The backend health check at `https://DEV_BACKEND_DOMAIN/health` should return `{"status":"ok"}`.

Once the user confirms dev is working, proceed to prod.

---

## Phase 13: Push to `release` — deploy prod environment

Push the `init-config` branch as the `release` branch to the deployment repository. The prod project's Cloud Build triggers (created in Phase 9) will fire automatically.

```bash
git push app init-config:release
```

Tell the user:

> Pushed to the `release` branch of the deployment repository.
>
> Build status: `https://console.cloud.google.com/cloud-build/builds?project=PROD_PROJECT_ID`

Wait up to 30 seconds. If `backend-deploy` and `frontend-deploy` do **not** appear automatically, it means the pushed commit did not change any files under `backend/**/*` or `frontend/**/*` (e.g., the most recent commit was a Terraform-only change). In that case, run them manually:

```bash
gcloud builds triggers run backend-deploy --branch=release --project=PROD_PROJECT_ID
gcloud builds triggers run frontend-deploy --branch=release --project=PROD_PROJECT_ID
```

Tell the user:

> Two builds are running:
> - `backend-deploy` → deploys `backend-app` to Cloud Run (prod)
> - `frontend-deploy` → deploys `frontend-app` to Cloud Run (prod)
>
> Let me know when both succeed.

Wait for the user to confirm both prod builds succeed.

---

## Phase 14: Apply prod domain mappings

Enable domain mappings by editing `infra/prod/_locals.tf`:

Change:
```hcl
  enable_domain_mapping = false
```
to:
```hcl
  enable_domain_mapping = true
```

Then apply:

```bash
cd infra/prod && terraform apply -auto-approve
```

Commit and push to the deployment repo:

```bash
git add infra/prod/_locals.tf
git commit -m "Enable prod domain mappings"
git push app init-config:release
```

After apply, tell the user:

> Please add the following DNS records for the prod domains. All Cloud Run custom domains use a CNAME pointing to `ghs.googlehosted.com.`:
>
> | Domain | Type | Value |
> |---|---|---|
> | **PROD_FRONTEND_DOMAIN** | CNAME | `ghs.googlehosted.com.` |
> | **PROD_BACKEND_DOMAIN** | CNAME | `ghs.googlehosted.com.` |
>
> Add these CNAME records in your DNS provider.
> You can monitor SSL certificate issuance at: `https://console.cloud.google.com/run/domains?project=PROD_PROJECT_ID`

---

## Phase 15: Verify prod environment and summarize

```bash
gcloud run services list --region=REGION --project=PROD_PROJECT_ID
```

Confirm `backend-app` and `frontend-app` are `READY`.

Check Cloud Build triggers in both projects:

```bash
gcloud builds triggers list --project=DEV_PROJECT_ID
gcloud builds triggers list --project=PROD_PROJECT_ID
```

Summarize the completed deployment:

- **Deployment repository**: `https://github.com/GITHUB_OWNER/GITHUB_REPO`
- **Dev environment**: `https://DEV_FRONTEND_DOMAIN`
  - Auto-deploys on every push to `main` in the deployment repository
- **Prod environment**: `https://PROD_FRONTEND_DOMAIN`
  - Auto-deploys on every push to `release` in the deployment repository
- **Release process**: merge `main` into `release` and push → auto-deploys to prod
- **Dev build status**: `https://console.cloud.google.com/cloud-build/builds?project=DEV_PROJECT_ID`
- **Prod build status**: `https://console.cloud.google.com/cloud-build/builds?project=PROD_PROJECT_ID`

---

## Error handling

- `gcloud` permission error → remind user to run `gcloud auth login` and `gcloud auth application-default login`, and verify project permissions.
- `terraform apply` failure → show the full error and suggest fixes before retrying.
- Cloud Build failure → link to the build log URL for diagnosis.
- Resource already exists (bucket, SA) → use `terraform import` to bring it under Terraform management before applying.
