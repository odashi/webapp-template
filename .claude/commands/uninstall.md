---
allowed-tools: Bash(gcloud:*), Bash(terraform:*), Bash(git:*), Bash(find:*), Bash(grep:*), Bash(ls:*), Bash(mkdir:*), Bash(date:*), Bash(uname:*), Bash(pwd:*), Read, Edit, Write
description: Interactive wizard to remove all GCP resources created by /install, stopping all billing
---

# Uninstall Wizard

You are an interactive uninstall wizard for this webapp template. This wizard removes all Google Cloud resources created by the `/install` wizard, stopping all GCP billing. The GitHub deployment repository is **not** deleted — the user can do that manually if desired.

Follow these phases in order. **Do not skip phases.** Confirm with the user before each destructive action.

---

## Logging policy

This wizard keeps a **detailed session log** at `logs/uninstall-TIMESTAMP.md` (created in Phase 0a). The log serves as feedback to the webapp-template developers — record everything, including errors, unexpected output, and any friction the user encounters.

**After every phase completes**, append a log entry that includes:

- Phase name and completion time (run `date '+%Y-%m-%d %H:%M:%S'`)
- Every shell command run, with **complete stdout and stderr verbatim** in fenced code blocks — do not summarize or truncate
- Any errors or unexpected output, clearly marked with `**Error:**`
- What the user said at each confirmation prompt
- Any resources that failed to delete and required manual cleanup
- Any friction, confusion, workarounds, or unexpected behavior — even minor ones

Use Bash (`>>` append) to write entries to the log file. The log is local only; do not commit it to the template repository (`origin`).

At the end of the wizard, ask the user for open-ended feedback and append their response to the log.

---

## Phase 0: Set communication language

Check whether `CLAUDE.md` exists at the repository root and contains a `## Language` section. If it does, use that language for this session. If not, ask the user which language to use and continue in that language.

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

Use the Write tool to create `logs/uninstall-TIMESTAMP.md` (replace `TIMESTAMP` with the value above). Fill in the header values by running the commands shown:

```markdown
# Uninstall Wizard Log

- **Wizard**: /uninstall
- **Started**: (output of: date '+%Y-%m-%d %H:%M:%S')
- **Working directory**: (output of: pwd)
- **Git branch**: (output of: git branch --show-current)
- **Platform**: (output of: uname -a)

---
```

All subsequent log entries append to this file using Bash `>>`.

**Log entry (Phase 0):** Append the chosen language and whether it was read from CLAUDE.md or provided by the user.

---

## Phase 1: Read configuration

Read `install.json` at the repository root and extract:

- `REGION` = `.region.default`
- `DEV_PROJECT_ID` = `.dev.project_id`
- `PROD_PROJECT_ID` = `.prod.project_id`
- `GITHUB_OWNER` = `.github.owner`
- `GITHUB_REPO` = `.github.name`
- `DEV_FRONTEND_DOMAIN` = `.domains.dev.frontend`
- `PROD_FRONTEND_DOMAIN` = `.domains.prod.frontend`

If the file is missing or still has placeholder values, tell the user and stop — there is nothing to uninstall.

Show the extracted values and confirm before proceeding.

**Log entry:** Append all extracted config values and any missing/placeholder fields found.

---

## Phase 1b: Ensure on install branch

The Terraform files with real project values exist only on the `install` branch.

```bash
git branch --show-current
```

If not on `install`, switch:

```bash
git checkout install
```

If `install` does not exist, tell the user there is nothing to uninstall (the install wizard was never completed on this machine) and stop.

**Log entry:** Append which branch was active and what action was taken.

---

## Phase 2: Confirm uninstall

Tell the user exactly what will be deleted and ask for explicit confirmation. Do not proceed unless the user says yes.

> **This will permanently delete the following resources. This cannot be undone.**
>
> **Dev project (`DEV_PROJECT_ID`):**
> - Cloud Run services: `backend-app`, `frontend-app`
> - HTTPS load balancer (static IP, SSL cert, URL map, NEGs, backend services)
> - Cloud Build triggers: `terraform-plan`, `terraform-apply`, `backend-deploy`, `frontend-deploy`
> - Artifact Registry repository: `images` (and all Docker images inside)
> - IAM service accounts: `terraform`, `backend-builder`, `backend-runner`, `frontend-builder`, `frontend-runner`
> - IAM role bindings for all of the above
> - GCS bucket: `DEV_PROJECT_ID-terraform` (Terraform state)
> - GCP APIs will be disabled: Artifact Registry, Cloud Build, Cloud Resource Manager, IAM, Cloud Run
>
> **Prod project (`PROD_PROJECT_ID`):**
> - Same set of resources as above
>
> **Not deleted:**
> - The GCP projects themselves (`DEV_PROJECT_ID`, `PROD_PROJECT_ID`)
> - The GitHub repository (`GITHUB_OWNER/GITHUB_REPO`) — you can delete it manually
> - DNS records — you will need to remove them from your DNS provider manually
>
> Type **yes** to proceed, or anything else to cancel.

If the user does not confirm with "yes", stop the wizard.

**Log entry:** Append whether the user confirmed or cancelled.

---

## Phase 3: Remove lifecycle restrictions from Terraform

Several Terraform resources have `prevent_destroy = true` lifecycle rules that prevent `terraform destroy` from removing them. Remove these before proceeding.

Edit `infra/modules/terraform/storage.tf` — remove the `lifecycle` block entirely:

From:
```hcl
resource "google_storage_bucket" "terraform" {
  name                        = "${var.project.id}-terraform"
  location                    = var.region.storage_default
  uniform_bucket_level_access = true

  lifecycle {
    prevent_destroy = true
  }
}
```
To:
```hcl
resource "google_storage_bucket" "terraform" {
  name                        = "${var.project.id}-terraform"
  location                    = var.region.storage_default
  uniform_bucket_level_access = true
}
```

Edit `infra/modules/terraform/iam.tf` — remove both `lifecycle` blocks:

From:
```hcl
resource "google_service_account" "terraform" {
  account_id   = "terraform"
  display_name = "Terraform service account"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project_iam_member" "owner" {
  project = var.project.id
  role    = "roles/owner"
  member  = google_service_account.terraform.member

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account_iam_member" "cloudbuild_impersonation" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.project.number}@cloudbuild.gserviceaccount.com"
}
```
To:
```hcl
resource "google_service_account" "terraform" {
  account_id   = "terraform"
  display_name = "Terraform service account"
}

resource "google_project_iam_member" "owner" {
  project = var.project.id
  role    = "roles/owner"
  member  = google_service_account.terraform.member
}

resource "google_service_account_iam_member" "cloudbuild_impersonation" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.project.number}@cloudbuild.gserviceaccount.com"
}
```

Edit `infra/dev/services.tf` — remove the `lifecycle` block:

From:
```hcl
resource "google_project_service" "common" {
  for_each = toset(local.enabled_services)
  service  = each.key
  lifecycle {
    prevent_destroy = true
  }
}
```
To:
```hcl
resource "google_project_service" "common" {
  for_each = toset(local.enabled_services)
  service  = each.key
}
```

Edit `infra/prod/services.tf` — same change as `infra/dev/services.tf`.

Commit these changes:

```bash
git add infra/modules/terraform/storage.tf infra/modules/terraform/iam.tf infra/dev/services.tf infra/prod/services.tf
git commit -m "Remove lifecycle restrictions for uninstall"
```

**Log entry:** Append the list of files edited to remove lifecycle blocks, and the git commit output.

---

## Phase 4: Teardown prod environment

### 4-1. Delete Cloud Run services

Cloud Run services are not managed by Terraform — they were deployed by Cloud Build. Delete them manually:

```bash
gcloud run services delete backend-app --region=REGION --project=PROD_PROJECT_ID --quiet 2>/dev/null || true
gcloud run services delete frontend-app --region=REGION --project=PROD_PROJECT_ID --quiet 2>/dev/null || true
```

The `|| true` handles the case where the service was never deployed or was already deleted.

### 4-2. Delete Artifact Registry repository

The AR repository cannot be destroyed by Terraform if it contains images. Delete it via gcloud (which also removes all images), then remove the repository and its dependent IAM bindings from Terraform state:

```bash
gcloud artifacts repositories delete images --location=REGION --project=PROD_PROJECT_ID --quiet 2>/dev/null || true
```

Then remove from Terraform state so `terraform destroy` does not try to delete them again:

```bash
cd infra/prod && terraform state rm \
  module.common.google_artifact_registry_repository.images \
  module.frontend.google_artifact_registry_repository_iam_member.builder_artifact_writer \
  module.backend.google_artifact_registry_repository_iam_member.builder_artifact_writer
```

If any `terraform state rm` entry fails because the resource is not in state (e.g., it was never created), that is fine — continue.

### 4-3. Migrate Terraform state from GCS to local

The prod Terraform state is stored in the GCS bucket. Migrate it to local so the bucket's contents become the local state file. Edit `infra/prod/main.tf` to comment out the `backend "gcs"` block:

From:
```hcl
  backend "gcs" {
    bucket = "PROD_PROJECT_ID-terraform"
  }
```
To:
```hcl
  # backend "gcs" {
  #   bucket = "PROD_PROJECT_ID-terraform"
  # }
```

Then migrate state from GCS to local:

```bash
cd infra/prod && terraform init -migrate-state
```

Type `yes` when prompted.

### 4-4. Delete GCS Terraform state bucket

The GCS bucket may still contain objects after state migration (Terraform does not always clean up the remote state file). Delete the bucket and all its contents via gcloud, then remove it from Terraform state:

```bash
gcloud storage rm -r gs://PROD_PROJECT_ID-terraform/ 2>/dev/null || true
cd infra/prod && terraform state rm module.terraform.google_storage_bucket.terraform
```

### 4-5. Destroy prod resources

Run Terraform destroy for the prod project:

```bash
cd infra/prod && terraform destroy -auto-approve
```

This will remove:
- Cloud Build triggers
- IAM service accounts and role bindings
- GCP API enablements

Wait for completion. If any resource fails to destroy, note the error and continue — the remaining resources can be removed manually via the GCP console.

Confirm with the user before proceeding to dev.

**Log entry:** Append the full output of all prod teardown commands: Cloud Run deletions, AR repository deletion, `terraform state rm`, state migration, GCS bucket deletion, and `terraform destroy`. Note any resources that failed to delete and how they were handled.

---

## Phase 5: Teardown dev environment

### 5-1. Delete Cloud Run services

```bash
gcloud run services delete backend-app --region=REGION --project=DEV_PROJECT_ID --quiet 2>/dev/null || true
gcloud run services delete frontend-app --region=REGION --project=DEV_PROJECT_ID --quiet 2>/dev/null || true
```

### 5-2. Delete Artifact Registry repository

```bash
gcloud artifacts repositories delete images --location=REGION --project=DEV_PROJECT_ID --quiet 2>/dev/null || true
```

Remove the repository and its dependent IAM bindings from Terraform state:

```bash
cd infra/dev && terraform state rm \
  module.common.google_artifact_registry_repository.images \
  module.frontend.google_artifact_registry_repository_iam_member.builder_artifact_writer \
  module.backend.google_artifact_registry_repository_iam_member.builder_artifact_writer
```

### 5-3. Migrate Terraform state from GCS to local

Edit `infra/dev/main.tf` to comment out the `backend "gcs"` block:

From:
```hcl
  backend "gcs" {
    bucket = "DEV_PROJECT_ID-terraform"
  }
```
To:
```hcl
  # backend "gcs" {
  #   bucket = "DEV_PROJECT_ID-terraform"
  # }
```

Migrate state:

```bash
cd infra/dev && terraform init -migrate-state
```

Type `yes` when prompted.

### 5-4. Delete GCS Terraform state bucket

```bash
gcloud storage rm -r gs://DEV_PROJECT_ID-terraform/ 2>/dev/null || true
cd infra/dev && terraform state rm module.terraform.google_storage_bucket.terraform
```

### 5-5. Destroy dev resources

```bash
cd infra/dev && terraform destroy -auto-approve
```

**Log entry:** Append the full output of all dev teardown commands: Cloud Run deletions, AR repository deletion, `terraform state rm`, state migration, GCS bucket deletion, and `terraform destroy`. Note any resources that failed to delete and how they were handled.

---

## Phase 6: Verify resource deletion

After both teardowns, verify that all GCP resources have been removed from both projects. Run the checks below for prod first, then dev. Report all results to the user.

### 6-1. Verify prod project

Run each command and capture the output:

**Cloud Run services:**
```bash
gcloud run services list --region=REGION --project=PROD_PROJECT_ID --format="table(metadata.name,status.url)"
```

**Cloud Build triggers:**
```bash
gcloud builds triggers list --project=PROD_PROJECT_ID --format="table(name,createTime)"
```

**Artifact Registry repositories:**
```bash
gcloud artifacts repositories list --location=REGION --project=PROD_PROJECT_ID --format="table(name,format)"
```

**IAM service accounts (custom — excludes default Google-managed accounts):**
```bash
gcloud iam service-accounts list --project=PROD_PROJECT_ID --format="table(email,displayName)" --filter="NOT email~'(developer\.gserviceaccount|appspot\.gserviceaccount|cloudservices\.gserviceaccount)'"
```

**GCS buckets:**
```bash
gcloud storage buckets list --project=PROD_PROJECT_ID --format="table(name,location)"
```

### 6-2. Verify dev project

Repeat the same checks for the dev project:

**Cloud Run services:**
```bash
gcloud run services list --region=REGION --project=DEV_PROJECT_ID --format="table(metadata.name,status.url)"
```

**Cloud Build triggers:**
```bash
gcloud builds triggers list --project=DEV_PROJECT_ID --format="table(name,createTime)"
```

**Artifact Registry repositories:**
```bash
gcloud artifacts repositories list --location=REGION --project=DEV_PROJECT_ID --format="table(name,format)"
```

**IAM service accounts (custom):**
```bash
gcloud iam service-accounts list --project=DEV_PROJECT_ID --format="table(email,displayName)" --filter="NOT email~'(developer\.gserviceaccount|appspot\.gserviceaccount|cloudservices\.gserviceaccount)'"
```

**GCS buckets:**
```bash
gcloud storage buckets list --project=DEV_PROJECT_ID --format="table(name,location)"
```

### 6-3. Report results

After running all checks, report to the user:

- If all commands returned **empty output**: tell the user all resources have been successfully removed.
- If **any resources remain**: list them clearly by project and resource type, and provide the manual deletion commands:

| Resource type | Deletion command |
|---|---|
| Cloud Run service | `gcloud run services delete NAME --region=REGION --project=PROJECT_ID --quiet` |
| Cloud Build trigger | `gcloud builds triggers delete TRIGGER_ID --project=PROJECT_ID --quiet` |
| Artifact Registry repo | `gcloud artifacts repositories delete NAME --location=REGION --project=PROJECT_ID --quiet` |
| IAM service account | `gcloud iam service-accounts delete SA_EMAIL --quiet` |
| GCS bucket | `gcloud storage rm -r gs://BUCKET_NAME/` |

Tell the user that Terraform-unmanaged resources (e.g., Cloud Run services deployed by Cloud Build, or resources created manually) must be deleted via these gcloud commands; they will not be removed by `terraform destroy`.

**Log entry:** Append the full output of all verification commands for both projects. List any resources that remained and required manual cleanup.

---

## Phase 7: Summary

Tell the user:

> **Uninstall complete.** All GCP resources in both projects have been deleted and billing has stopped.
>
> **Remaining manual steps (if desired):**
>
> 1. **Remove DNS records**: Delete the A records for your frontend domains from your DNS provider:
>    - `DEV_FRONTEND_DOMAIN`
>    - `PROD_FRONTEND_DOMAIN`
>
> 2. **Delete the GitHub repository**: The deployment repository at `https://github.com/GITHUB_OWNER/GITHUB_REPO` still exists. Delete it from GitHub if you no longer need it.
>
> 3. **Disconnect Cloud Build GitHub App** (optional): If you no longer want the Cloud Build GitHub App connected to your GitHub account, you can remove it from your GitHub account's installed apps at `https://github.com/settings/installations`.
>
> The `install` branch on this local repository still contains your deployment configuration. You can delete it with `git branch -D install` if you no longer need it.

Then ask the user:

> The uninstall is complete. Before we finish, do you have any feedback on the wizard? For example:
> - Were any steps confusing or unclear?
> - Did any resources fail to delete unexpectedly?
> - Are there steps you wish were automated?
> - Any other suggestions for improvement?

Append their response (verbatim) to the log under a `## User Feedback` section, then write a final `## Session End` section with the completion timestamp:

```bash
date '+%Y-%m-%d %H:%M:%S'
```

Tell the user the log has been saved to `logs/uninstall-TIMESTAMP.md` and can be shared with the webapp-template developers as feedback.

---

## Error handling

- `gcloud` permission error → remind user to run `gcloud auth login` and `gcloud auth application-default login`.
- `terraform destroy` fails on a specific resource → note the error, instruct the user to delete the resource manually via the GCP console, then remove it from Terraform state with `terraform state rm <resource_address>` and retry `terraform destroy`.
- GCS bucket still has objects after state migration → this is expected; Phase 4-4/5-4 handles it with `gcloud storage rm -r` followed by `terraform state rm`.
- Terraform state is already local (GCS backend was already commented out) → skip the migration step and proceed directly to `terraform destroy`.
