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

## Logging policy

This wizard keeps a **detailed session log** at `logs/install-TIMESTAMP.md` (created in Phase 0a). The log serves as feedback to the webapp-template developers — record everything, including errors, unexpected output, and any friction the user encounters.

**After every phase completes**, append a log entry that includes:

- Phase name and completion time (run `date '+%Y-%m-%d %H:%M:%S'`)
- Every shell command run, with **complete stdout and stderr verbatim** in fenced code blocks — do not summarize or truncate
- Any errors or unexpected output, clearly marked with `**Error:**`
- What the user said at each confirmation prompt (e.g., "User confirmed: yes", "User provided language: Japanese")
- Any manual steps the user performed (e.g., Cloud Build GitHub App connection)
- Any friction, confusion, workarounds, or unexpected behavior — even minor ones

Use Bash (`>>` append) to write entries to the log file. The log is local only; do not commit it to the template repository (`origin`).

At the end of the wizard, ask the user for open-ended feedback and append their response to the log.

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

**Log entry:** Append to the log: chosen language, and the CLAUDE.md change made.

---

## Phase 0a: Create log file

Get the current timestamp:

```bash
date '+%Y%m%d-%H%M%S'
```

Create the `logs/` directory if it does not exist, and ensure it is excluded from git:

```bash
mkdir -p logs
grep -qxF 'logs/' .gitignore 2>/dev/null || echo 'logs/' >> .gitignore
```

Use the Write tool to create `logs/install-TIMESTAMP.md` (replace `TIMESTAMP` with the value above). Fill in the header values by running the commands shown:

```markdown
# Install Wizard Log

- **Wizard**: /install
- **Started**: (output of: date '+%Y-%m-%d %H:%M:%S')
- **Working directory**: (output of: pwd)
- **Git branch**: (output of: git branch --show-current)
- **Platform**: (output of: uname -a)

---
```

All subsequent log entries append to this file using Bash `>>`.

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

**Log entry:** Append tool version outputs and which tools were present/missing.

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
> - Enable APIs: Artifact Registry, Cloud Build, Cloud Resource Manager, Compute Engine, IAM, IAP, Cloud Run
> - Create a GCS bucket for Terraform state
> - Create a Terraform service account with the necessary IAM roles
> - Create an Artifact Registry repository for Docker images
> - Create Cloud Build triggers (CI/CD pipelines for backend, frontend, and Terraform)
> - Deploy backend and frontend applications to Cloud Run
> - Create an HTTPS load balancer with SSL certificate for your custom domain
>
> **Google Cloud changes (prod project: `PROD_PROJECT_ID`):**
> - Same as above for the prod project
>
> **Local file changes:**
> - `CLAUDE.md` — language preference (already done in Phase 0)
> - `infra/dev/_locals.tf`, `infra/dev/main.tf` — filled with your dev project values and IAP allowed members
> - `infra/prod/_locals.tf`, `infra/prod/main.tf` — filled with your prod project values
>
> Note: placeholder values are only filled on the local `install` branch. The template repository (`origin`) will keep placeholder values on `main`.
>
> **DNS changes (manual):**
> - You will need to add A records in your DNS provider pointing to the load balancer IP (shown later in the wizard).
>
> Do you want to proceed?

Wait for the user to confirm before continuing.

**Log entry:** Append the summary of what the wizard will do and whether the user confirmed.

---

## Phase 1: Read configuration from install.json

Read `install.json` at the repository root.

If the file does not exist, tell the user:

> `install.json` was not found at the repository root. Please create it using the placeholder values in the existing template as a guide.

If the file exists, read it and validate that **no value in the file contains `[[[`** — any occurrence of `[[[` means that field has not been filled in yet.

Check each field and list any that still contain `[[[`. If any are found, tell the user:

> Please edit `install.json` and replace all `[[[...]]]` placeholders with your actual values, then run the wizard again.

The fields to fill in are:
- `iap.support_email` — email shown on the OAuth consent screen (e.g. `admin@example.com`)
- `region.default` — GCP region (e.g. `asia-northeast1`)
- `region.storage` — GCS storage region (e.g. `ASIA-NORTHEAST1`)
- `dev.project_id` — dev GCP project ID
- `dev.project_number` — dev GCP project number (12-digit)
- `prod.project_id` — prod GCP project ID
- `prod.project_number` — prod GCP project number (12-digit)
- `github.owner` — GitHub username or organization
- `github.name` — deployment repository name (will be created in Phase 6)
- `domains.dev.frontend` — dev frontend custom domain
- `domains.prod.frontend` — prod frontend custom domain

Do not proceed until the file is valid. If the user says they have updated it, re-read and re-validate.

Once valid, extract and store the following variables for use throughout the wizard:

- `IAP_SUPPORT_EMAIL` = `.iap.support_email`
- `REGION` = `.region.default`
- `STORAGE_REGION` = `.region.storage`
- `DEV_PROJECT_ID` = `.dev.project_id`
- `DEV_PROJECT_NUMBER` = `.dev.project_number`
- `PROD_PROJECT_ID` = `.prod.project_id`
- `PROD_PROJECT_NUMBER` = `.prod.project_number`
- `GITHUB_OWNER` = `.github.owner`
- `GITHUB_REPO` = `.github.name`
- `DEV_FRONTEND_DOMAIN` = `.domains.dev.frontend`
- `PROD_FRONTEND_DOMAIN` = `.domains.prod.frontend`

Show the user the values that were read and confirm before proceeding.

**Log entry:** Append all extracted values from `install.json` and any validation errors found.

---

## Phase 1b: Ensure working on install branch

`install` is a **local-only** branch used to keep deployment configuration separate from template improvements. It is never pushed to `origin` (the template repo).

Check the current branch:

```bash
git branch --show-current
```

- If already on `install`: continue.
- If `install` exists locally but is not checked out: `git checkout install`
- If `install` does not exist yet: `git checkout -b install`

Tell the user:

> Configuration changes will be made on the `install` branch. This branch is never pushed to the template repository (`origin`) — it is only pushed to the deployment repository (`app`). Template improvements stay on `main`.

**Log entry:** Append which branch was active and what action was taken (already on install / checked out / created new).

---

## Phase 2: Fill in configuration placeholders

Using the values read from `install.json`, edit the Terraform files to replace all `[[[...]]]` placeholders. Each placeholder name matches the JSON path of the corresponding field in `install.json`.

Edit `infra/dev/_locals.tf`:
- `[[[dev.project_id]]]` → `DEV_PROJECT_ID`
- `[[[dev.project_number]]]` → `DEV_PROJECT_NUMBER`
- `[[[region.default]]]` → `REGION`
- `[[[region.storage]]]` → `STORAGE_REGION`
- `[[[github.owner]]]` → `GITHUB_OWNER`
- `[[[github.name]]]` → `GITHUB_REPO`
- `[[[domains.dev.frontend]]]` → `DEV_FRONTEND_DOMAIN`
- `[[[iap.support_email]]]` → `IAP_SUPPORT_EMAIL`

Then ask the user:

> Who should have access to the dev environment via IAP? Enter your email address (e.g. `alice@example.com`):

Store the response as `DEV_IAP_EMAIL`. Edit the `iap_allowed_members` block in `infra/dev/_locals.tf` to add the user's address:

```hcl
iap_allowed_members = [
  "user:DEV_IAP_EMAIL",
]
```

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
- `[[[iap.support_email]]]` → `IAP_SUPPORT_EMAIL`

Edit `infra/prod/main.tf`:
- `[[[prod.project_id]]]-terraform` → `PROD_PROJECT_ID-terraform`

After all edits, show the user a brief summary of every file changed. Ask them to confirm before proceeding.

**Log entry:** Append the list of files edited, the email address entered for dev IAP access, and any issues encountered during placeholder substitution.

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
  compute.googleapis.com \
  iam.googleapis.com \
  iap.googleapis.com \
  run.googleapis.com \
  --project=DEV_PROJECT_ID
```

Confirm with the user before proceeding.

**Log entry:** Append the full output of the `gcloud services enable` command for dev, including any errors.

---

## Phase 4: Bootstrap prod GCP project

### 4-1. Enable required APIs in prod project

```bash
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  cloudresourcemanager.googleapis.com \
  compute.googleapis.com \
  iam.googleapis.com \
  iap.googleapis.com \
  run.googleapis.com \
  --project=PROD_PROJECT_ID
```

Confirm with the user before proceeding.

**Log entry:** Append the full output of the `gcloud services enable` command for prod, including any errors.

---

## Phase 5: Verify git repository

```bash
git -C . rev-parse --is-inside-work-tree 2>/dev/null && echo "git_exists" || echo "no_git"
```

If `no_git`, initialize, create `main`, and then create `install`:

```bash
git init
git checkout -b main
git checkout -b install
```

If git already exists, confirm the current branch is `install` (Phase 1b should have handled this).

**Log entry:** Append the git status check result.

---

## Phase 6: Create deployment repository and push

This phase creates the GitHub deployment repository and pushes the configured code to it. The deployment repository (`app` remote) is separate from the template repository (`origin`) and receives all future deployment pushes. The `origin` remote always retains placeholder values on `main`.

### 6-1. Generate frontend package lock file

Required for Docker's `npm ci` during Cloud Build:

```bash
cd frontend && npm install
```

### 6-2. Commit all changes on install

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

Push the `install` branch (which contains real configuration values) as `main` to the deployment repository:

```bash
git push app install:main
```

This is the only push to the deployment repo `main` branch that originates from `install`. From here on, everyday development happens in the deployment repository itself, not the template.

Confirm with the user before proceeding.

**Log entry:** Append the outputs of `npm install`, `git commit`, `gh repo create`, and `git push` commands; note whether `gh` was used or the user created the repo manually.

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

**Log entry:** Append how long the user took to complete the manual Cloud Build GitHub App connection, and any issues they reported (e.g., difficulty finding the Triggers page, auth dialogs, repository selection errors).

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

**Log entry:** Append the full output of `terraform init`, `terraform plan`, and `terraform apply` for dev; the state migration output; any errors and how they were resolved.

---

### 8-5. Configure dev DNS

SSL certificate provisioning begins once the DNS A record resolves — configure it now so provisioning runs in the background while the remaining phases complete.

Get the load balancer IP address:

```bash
cd infra/dev && terraform output -raw lb_ip_address
```

Tell the user:

> Please add the following DNS A record now to start SSL certificate provisioning:
>
> | Domain | Type | Value |
> |---|---|---|
> | **DEV_FRONTEND_DOMAIN** | A | `<lb_ip_address>` |
>
> The HTTPS load balancer routes traffic as follows:
> - `https://DEV_FRONTEND_DOMAIN/` → frontend
> - `https://DEV_FRONTEND_DOMAIN/api/` → backend
>
> No separate DNS record is needed for the backend.
>
> SSL certificate provisioning is automatic and may take **15–60 minutes** after DNS propagates. You can monitor status at:
> `https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers?project=DEV_PROJECT_ID`
>
> There is no need to wait for SSL before continuing — proceed to Phase 9 now.

Wait for the user to confirm the DNS record has been added, then continue.

**Log entry:** Append the lb_ip_address output and the DNS record the user needs to create.

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
git push app install:main
```

This push will trigger the dev Terraform CI (no-op since state is up to date).

**Log entry:** Append the full output of `terraform init`, `terraform plan`, `terraform apply`, and state migration for prod; any errors and how they were resolved.

---

### 9-5. Configure prod DNS

Configure prod DNS now so SSL provisioning starts while Cloud Build deploys are in progress.

Get the load balancer IP address:

```bash
cd infra/prod && terraform output -raw lb_ip_address
```

Tell the user:

> Please add the following DNS A record now to start SSL certificate provisioning:
>
> | Domain | Type | Value |
> |---|---|---|
> | **PROD_FRONTEND_DOMAIN** | A | `<lb_ip_address>` |
>
> The HTTPS load balancer routes traffic as follows:
> - `https://PROD_FRONTEND_DOMAIN/` → frontend
> - `https://PROD_FRONTEND_DOMAIN/api/` → backend
>
> No separate DNS record is needed for the backend.
>
> **Note:** Prod IAP is enabled with an empty `iap_allowed_members` list, so the environment is inaccessible even after SSL is active. Add email addresses to `iap_allowed_members` in `infra/prod/_locals.tf` and run `terraform apply` to grant access.
>
> SSL certificate provisioning may take **15–60 minutes** after DNS propagates. Monitor status at:
> `https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers?project=PROD_PROJECT_ID`
>
> There is no need to wait for SSL before continuing — proceed to Phase 10 now.

Wait for the user to confirm the DNS record has been added, then continue.

**Log entry:** Append the lb_ip_address output and the DNS record the user needs to create.

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

**Log entry:** Append the trigger list output, which triggers were run (manual or auto), and the time taken for dev builds to complete. Note whether the user had to run triggers manually or they fired automatically.

---

## Phase 11: Verify dev SSL certificate

Dev DNS was configured in Phase 8-5. Check whether SSL certificate provisioning has completed:

Tell the user:

> Dev DNS was configured in Phase 8-5. Check SSL certificate status at:
> `https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers?project=DEV_PROJECT_ID`
>
> If the certificate status shows **ACTIVE**, the dev environment is ready to verify.
> If it still shows **PROVISIONING**, wait a few minutes and check again — provisioning can take up to 60 minutes total from when DNS was first configured.

Wait for the user to confirm the certificate is **ACTIVE** before proceeding to Phase 12.

**Log entry:** Append SSL certificate status and approximate time elapsed since DNS was configured in Phase 8-5.

---

## Phase 12: Verify dev environment

```bash
gcloud run services list --region=REGION --project=DEV_PROJECT_ID
```

Confirm `backend-app` and `frontend-app` are `READY`.

Ask the user to open `https://DEV_FRONTEND_DOMAIN` and confirm it loads. The backend health check at `https://DEV_FRONTEND_DOMAIN/api/health` should return `{"status":"ok"}`.

Once the user confirms dev is working, proceed to prod.

**Log entry:** Append the Cloud Run services list output; note whether the user confirmed the frontend loaded and the backend health check passed.

---

## Phase 13: Deploy prod environment via PR merge

Instead of pushing `install:release` directly, create a PR from `main` to `release` in the deployment repository. The merge commit's diff spans all accumulated changes, ensuring all Cloud Build path-filter triggers fire correctly.

### 13-1. Create an empty initial `release` branch

Create an orphan initial commit and push it as the `release` branch. This gives the PR merge commit a diff that covers all files under `backend/**/*` and `frontend/**/*`, guaranteeing all Cloud Build service triggers fire.

```bash
git push app "$(git commit-tree "$(git hash-object -t tree /dev/null)" -m 'Initialize release branch')":refs/heads/release
```

### 13-2. Open a PR from `main` to `release`

```bash
gh pr create \
  --repo GITHUB_OWNER/GITHUB_REPO \
  --base release \
  --head main \
  --title "Deploy to prod: initial release" \
  --body "Initial production deployment."
```

Tell the user:

> A pull request has been opened from `main` to `release` in the deployment repository.
> Please review and merge the PR to trigger the first prod deployment.
>
> PR: `https://github.com/GITHUB_OWNER/GITHUB_REPO/pulls`
>
> After merging, both `backend-deploy` and `frontend-deploy` Cloud Build triggers will fire automatically because the merge commit's diff covers all application files.
>
> Build status: `https://console.cloud.google.com/cloud-build/builds?project=PROD_PROJECT_ID`

### 13-3. Wait for prod builds

Wait for the user to merge the PR and confirm both prod builds succeed.

> Two builds are running:
> - `backend-deploy` → deploys `backend-app` to Cloud Run (prod)
> - `frontend-deploy` → deploys `frontend-app` to Cloud Run (prod)
>
> Let me know when both succeed.

**Log entry:** Append the PR URL, whether builds fired automatically after merge, and the time taken.

---

## Phase 14: Verify prod SSL certificate

Prod DNS was configured in Phase 9-5. Check whether SSL certificate provisioning has completed:

Tell the user:

> Prod DNS was configured in Phase 9-5. Check SSL certificate status at:
> `https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers?project=PROD_PROJECT_ID`
>
> If the certificate status shows **ACTIVE**, the prod environment is ready to verify.
> If it still shows **PROVISIONING**, wait a few minutes and check again — provisioning can take up to 60 minutes total from when DNS was first configured.

Wait for the user to confirm the certificate is **ACTIVE** before proceeding to Phase 15.

**Log entry:** Append SSL certificate status and approximate time elapsed since DNS was configured in Phase 9-5.

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
  - Backend API: `https://DEV_FRONTEND_DOMAIN/api/`
  - Auto-deploys on every push to `main` in the deployment repository
  - IAP: enabled; access restricted to members in `iap_allowed_members` in `infra/dev/_locals.tf`
- **Prod environment**: `https://PROD_FRONTEND_DOMAIN`
  - Backend API: `https://PROD_FRONTEND_DOMAIN/api/`
  - Auto-deploys on every push to `release` in the deployment repository
  - IAP: enabled, all access blocked by default; add members to `iap_allowed_members` in `infra/prod/_locals.tf` to grant access
- **Release process**: open a PR from `main` to `release` in the deployment repository and merge it → the merge commit triggers all relevant Cloud Build deploys automatically
- **Dev build status**: `https://console.cloud.google.com/cloud-build/builds?project=DEV_PROJECT_ID`
- **Prod build status**: `https://console.cloud.google.com/cloud-build/builds?project=PROD_PROJECT_ID`

**Log entry:** Append the Cloud Run services list output for prod and the Cloud Build triggers list for both projects.

Then ask the user:

> The installation is complete. Before we finish, do you have any feedback on the wizard? For example:
> - Were any steps confusing or unclear?
> - Did anything not work as expected?
> - Are there steps you wish were automated?
> - Any other suggestions for improvement?

Append their response (verbatim) to the log under a `## User Feedback` section, then write a final `## Session End` section with the completion timestamp:

```bash
date '+%Y-%m-%d %H:%M:%S'
```

Tell the user the log has been saved to `logs/install-TIMESTAMP.md` and can be shared with the webapp-template developers as feedback.

---

## Error handling

- `gcloud` permission error → remind user to run `gcloud auth login` and `gcloud auth application-default login`, and verify project permissions.
- `terraform apply` failure → show the full error and suggest fixes before retrying.
- Cloud Build failure → link to the build log URL for diagnosis.
- Resource already exists (bucket, SA) → use `terraform import` to bring it under Terraform management before applying.
