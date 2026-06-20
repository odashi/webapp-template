---
allowed-tools: Bash(gcloud:*), Bash(terraform:*), Bash(git:*), Bash(find:*), Bash(grep:*), Bash(ls:*), Read, Edit
description: Interactive wizard to remove all GCP resources created by /install, stopping all billing
---

# Uninstall Wizard

You are an interactive uninstall wizard for this webapp template. This wizard removes all Google Cloud resources created by the `/install` wizard, stopping all GCP billing. The GitHub deployment repository is **not** deleted — the user can do that manually if desired.

Follow these phases in order. **Do not skip phases.** Confirm with the user before each destructive action.

---

## Phase 0: Set communication language

Check whether `CLAUDE.md` exists at the repository root and contains a `## Language` section. If it does, use that language for this session. If not, ask the user which language to use and continue in that language.

---

## Phase 1: Read configuration

Read `deploy.config.json` at the repository root and extract:

- `REGION` = `.region.default`
- `DEV_PROJECT_ID` = `.dev.project_id`
- `PROD_PROJECT_ID` = `.prod.project_id`
- `GITHUB_OWNER` = `.github.owner`
- `GITHUB_REPO` = `.github.name`
- `DEV_FRONTEND_DOMAIN` = `.domains.dev.frontend`
- `DEV_BACKEND_DOMAIN` = `.domains.dev.backend`
- `PROD_FRONTEND_DOMAIN` = `.domains.prod.frontend`
- `PROD_BACKEND_DOMAIN` = `.domains.prod.backend`

If the file is missing or still has placeholder values, tell the user and stop — there is nothing to uninstall.

Show the extracted values and confirm before proceeding.

---

## Phase 1b: Ensure on init-config branch

The Terraform files with real project values exist only on the `init-config` branch.

```bash
git branch --show-current
```

If not on `init-config`, switch:

```bash
git checkout init-config
```

If `init-config` does not exist, tell the user there is nothing to uninstall (the install wizard was never completed on this machine) and stop.

---

## Phase 2: Confirm uninstall

Tell the user exactly what will be deleted and ask for explicit confirmation. Do not proceed unless the user says yes.

> **This will permanently delete the following resources. This cannot be undone.**
>
> **Dev project (`DEV_PROJECT_ID`):**
> - Cloud Run services: `backend-app`, `frontend-app`
> - Cloud Run domain mappings: `DEV_FRONTEND_DOMAIN`, `DEV_BACKEND_DOMAIN`
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

---

## Phase 4: Teardown dev environment

### 4-1. Delete Cloud Run services

Cloud Run services are not managed by Terraform — they were deployed by Cloud Build. Delete them manually:

```bash
gcloud run services delete backend-app --region=REGION --project=DEV_PROJECT_ID --quiet 2>/dev/null || true
gcloud run services delete frontend-app --region=REGION --project=DEV_PROJECT_ID --quiet 2>/dev/null || true
```

The `|| true` handles the case where the service was never deployed or was already deleted.

### 4-2. Delete Artifact Registry repository

The AR repository cannot be destroyed by Terraform if it contains images. Delete it via gcloud (which also removes all images), then remove it from Terraform state:

```bash
gcloud artifacts repositories delete images --location=REGION --project=DEV_PROJECT_ID --quiet 2>/dev/null || true
```

Then remove from Terraform state so `terraform destroy` does not try to delete it again:

```bash
cd infra/dev && terraform state rm module.common.google_artifact_registry_repository.images
```

If the `terraform state rm` command fails because the resource is not in state (e.g., it was never created), that is fine — continue.

### 4-3. Migrate Terraform state from GCS to local

The dev Terraform state is stored in the GCS bucket. We need to migrate it to local before destroying the bucket. Edit `infra/dev/main.tf` to comment out the `backend "gcs"` block:

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

Then migrate state from GCS to local:

```bash
cd infra/dev && terraform init -migrate-state
```

Type `yes` when prompted. After this, the GCS bucket is empty and can be deleted by Terraform.

### 4-4. Destroy dev resources

Run Terraform destroy for the dev project:

```bash
cd infra/dev && terraform destroy -auto-approve
```

This will remove:
- Cloud Build triggers
- IAM service accounts and role bindings
- GCS Terraform state bucket (now empty)
- GCP API enablements

Wait for completion. If any resource fails to destroy, note the error and continue — the remaining resources can be removed manually via the GCP console.

Confirm with the user before proceeding to prod.

---

## Phase 5: Teardown prod environment

### 5-1. Delete Cloud Run services

```bash
gcloud run services delete backend-app --region=REGION --project=PROD_PROJECT_ID --quiet 2>/dev/null || true
gcloud run services delete frontend-app --region=REGION --project=PROD_PROJECT_ID --quiet 2>/dev/null || true
```

### 5-2. Delete Artifact Registry repository

```bash
gcloud artifacts repositories delete images --location=REGION --project=PROD_PROJECT_ID --quiet 2>/dev/null || true
```

Remove from Terraform state:

```bash
cd infra/prod && terraform state rm module.common.google_artifact_registry_repository.images
```

### 5-3. Migrate Terraform state from GCS to local

Edit `infra/prod/main.tf` to comment out the `backend "gcs"` block:

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

Migrate state:

```bash
cd infra/prod && terraform init -migrate-state
```

Type `yes` when prompted.

### 5-4. Destroy prod resources

```bash
cd infra/prod && terraform destroy -auto-approve
```

---

## Phase 6: Summary

Tell the user:

> **Uninstall complete.** All GCP resources in both projects have been deleted and billing has stopped.
>
> **Remaining manual steps (if desired):**
>
> 1. **Remove DNS records**: Delete the CNAME records for your custom domains from your DNS provider:
>    - `DEV_FRONTEND_DOMAIN`
>    - `DEV_BACKEND_DOMAIN`
>    - `PROD_FRONTEND_DOMAIN`
>    - `PROD_BACKEND_DOMAIN`
>
> 2. **Delete the GitHub repository**: The deployment repository at `https://github.com/GITHUB_OWNER/GITHUB_REPO` still exists. Delete it from GitHub if you no longer need it.
>
> 3. **Disconnect Cloud Build GitHub App** (optional): If you no longer want the Cloud Build GitHub App connected to your GitHub account, you can remove it from your GitHub account's installed apps at `https://github.com/settings/installations`.
>
> The `init-config` branch on this local repository still contains your deployment configuration. You can delete it with `git branch -D init-config` if you no longer need it.

---

## Error handling

- `gcloud` permission error → remind user to run `gcloud auth login` and `gcloud auth application-default login`.
- `terraform destroy` fails on a specific resource → note the error, instruct the user to delete the resource manually via the GCP console, then remove it from Terraform state with `terraform state rm <resource_address>` and retry `terraform destroy`.
- GCS bucket still has objects after state migration → use `gcloud storage rm -r gs://DEV_PROJECT_ID-terraform/` to empty the bucket, then retry `terraform destroy`.
- Terraform state is already local (GCS backend was already commented out) → skip the migration step and proceed directly to `terraform destroy`.
