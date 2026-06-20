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

- `my-gcp-region`
- `MY-STORAGE-REGION`
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
- `my-gcp-region` → `REGION`
- `MY-STORAGE-REGION` → `STORAGE_REGION`
- `my-dev-project-id` → `DEV_PROJECT_ID`
- `000000000000` → `DEV_PROJECT_NUMBER`
- `my-github-owner` → `GITHUB_OWNER`
- `my-repo-name` → `GITHUB_REPO`
- `dev.example.com` → `DEV_FRONTEND_DOMAIN`
- `api-dev.example.com` → `DEV_BACKEND_DOMAIN`

Edit `infra/dev/main.tf`:
- `my-dev-project-id-terraform` → `DEV_PROJECT_ID-terraform`

Edit `infra/prod/_locals.tf`:
- `my-gcp-region` → `REGION`
- `MY-STORAGE-REGION` → `STORAGE_REGION`
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

This phase creates the GitHub deployment repository and pushes the configured code to it. The deployment repository (`app` remote) is separate from the template repository (`origin`) and receives all future deployment pushes. The `origin` remote (webapp-template) always retains placeholder values on `main`.

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

> GitHub に新しいリポジトリを作成してください:
> - URL: `https://github.com/new`
> - Owner: **GITHUB_OWNER**
> - Repository name: **GITHUB_REPO**
> - **README・.gitignore・ライセンスによる初期化は行わないでください**
>
> 作成が完了したら教えてください。

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

> Cloud Build の **両プロジェクト** に GitHub App を接続してください。
>
> **Dev プロジェクト:**
> 1. `https://console.cloud.google.com/cloud-build/triggers?project=DEV_PROJECT_ID` を開く
> 2. **Connect Repository** をクリック
> 3. ソースとして **GitHub (Cloud Build GitHub App)** を選択
> 4. GitHub を認証し、**GITHUB_OWNER/GITHUB_REPO** を選択してウィザードを完了
>
> **Prod プロジェクト:**
> 1. `https://console.cloud.google.com/cloud-build/triggers?project=PROD_PROJECT_ID` を開く
> 2. **Connect Repository** をクリック
> 3. ソースとして **GitHub (Cloud Build GitHub App)** を選択
> 4. GitHub を認証し、**GITHUB_OWNER/GITHUB_REPO** を選択してウィザードを完了
>
> 両方の接続が完了したら教えてください。

Note: if the GitHub App is already installed for that GitHub account from a previous project, step 4 may skip the authorization dialog and proceed directly to repository selection.

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

> dev プロジェクトのビルドが開始しました。
>
> ビルド状況: `https://console.cloud.google.com/cloud-build/builds?project=DEV_PROJECT_ID`
>
> 2つのビルドが実行されます:
> - `backend-deploy` → Cloud Run に `backend-app` をデプロイ
> - `frontend-deploy` → Cloud Run に `frontend-app` をデプロイ
>
> 通常 5〜10 分かかります。両方が完了したら教えてください。

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

> dev ドメインの DNS レコードを設定してください。Cloud Run のカスタムドメインはすべて `ghs.googlehosted.com.` への CNAME レコードです:
>
> | ドメイン | タイプ | 値 |
> |---|---|---|
> | **DEV_FRONTEND_DOMAIN** | CNAME | `ghs.googlehosted.com.` |
> | **DEV_BACKEND_DOMAIN** | CNAME | `ghs.googlehosted.com.` |
>
> DNS プロバイダにこれらの CNAME レコードを登録してください。反映には最大 1 時間かかる場合があります。
> なお、Cloud Console (`https://console.cloud.google.com/run/domains?project=DEV_PROJECT_ID`) では SSL 証明書の発行状況を確認できます。

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

> deployment リポジトリの `release` ブランチに push しました。
>
> ビルド状況: `https://console.cloud.google.com/cloud-build/builds?project=PROD_PROJECT_ID`

Wait up to 30 seconds. If `backend-deploy` and `frontend-deploy` do **not** appear automatically, it means the pushed commit did not change any files under `backend/**/*` or `frontend/**/*` (e.g., the most recent commit was a Terraform-only change). In that case, run them manually:

```bash
gcloud builds triggers run backend-deploy --branch=release --project=PROD_PROJECT_ID
gcloud builds triggers run frontend-deploy --branch=release --project=PROD_PROJECT_ID
```

> 2つのビルドが実行されます:
> - `backend-deploy` → Cloud Run に `backend-app` をデプロイ (prod)
> - `frontend-deploy` → Cloud Run に `frontend-app` をデプロイ (prod)
>
> 両方が完了したら教えてください。

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

> prod ドメインの DNS レコードを設定してください。Cloud Run のカスタムドメインはすべて `ghs.googlehosted.com.` への CNAME レコードです:
>
> | ドメイン | タイプ | 値 |
> |---|---|---|
> | **PROD_FRONTEND_DOMAIN** | CNAME | `ghs.googlehosted.com.` |
> | **PROD_BACKEND_DOMAIN** | CNAME | `ghs.googlehosted.com.` |
>
> DNS プロバイダにこれらの CNAME レコードを登録してください。
> なお、Cloud Console (`https://console.cloud.google.com/run/domains?project=PROD_PROJECT_ID`) では SSL 証明書の発行状況を確認できます。

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

- **デプロイ先リポジトリ**: `https://github.com/GITHUB_OWNER/GITHUB_REPO`
- **Dev 環境**: `https://DEV_FRONTEND_DOMAIN`
  - deployment リポジトリの `main` への push で自動デプロイ (dev プロジェクト)
- **Prod 環境**: `https://PROD_FRONTEND_DOMAIN`
  - deployment リポジトリの `release` への push で自動デプロイ (prod プロジェクト)
- **リリース方法**: `main` を `release` にマージして push → prod に自動デプロイ
- **Dev ビルド監視**: `https://console.cloud.google.com/cloud-build/builds?project=DEV_PROJECT_ID`
- **Prod ビルド監視**: `https://console.cloud.google.com/cloud-build/builds?project=PROD_PROJECT_ID`

---

## Error handling

- `gcloud` permission error → remind user to run `gcloud auth login` and verify project permissions.
- `terraform apply` failure → show the full error and suggest fixes before retrying.
- Cloud Build failure → link to the build log URL for diagnosis.
- Resource already exists (bucket, SA) → skip creation, note it was already done.
- Import already in state → skip import, continue.
