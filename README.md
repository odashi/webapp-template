# Webapp Template

A full-stack web application template with automated CI/CD on Google Cloud Platform, managed through [Claude Code](https://claude.ai/code).

## Stack

| Layer | Technology |
|---|---|
| Frontend | React 19, TypeScript, Vite (served via nginx on Cloud Run) |
| Backend | Python 3.13, FastAPI, uvicorn (Cloud Run) |
| Infrastructure | Terraform, Google Cloud Run, Artifact Registry |
| CI/CD | Google Cloud Build (triggered by GitHub pushes) |

## Architecture

This template uses a **two-environment model**: two independent GCP projects (`dev` and `prod`) with separate Cloud Build pipelines, Cloud Run services, Artifact Registry repositories, IAM, and Terraform state.

```
webapp-template/        ← this repository (template)
├── frontend/           # React + TypeScript app
├── backend/            # FastAPI app (Python, managed with uv)
├── infra/
│   ├── dev/            # Terraform root for dev project
│   ├── prod/           # Terraform root for prod project
│   └── modules/        # Shared Terraform modules
└── deploy.config.json  # Your deployment configuration (fill in before installing)
```

**Deployment flow:**
- Push to `main` in the deployment repository → auto-deploy to **dev**
- Push to `release` in the deployment repository → auto-deploy to **prod**

This repository (the template) stays clean with placeholder values. Your real configuration lives on a local `init-config` branch and is pushed to a separate deployment repository.

## Prerequisites

### Tools

Install the following before running the wizard:

| Tool | Purpose | Install |
|---|---|---|
| [Claude Code](https://claude.ai/code) | Runs the install/uninstall wizards | [docs](https://docs.anthropic.com/en/docs/claude-code/overview) |
| [gcloud CLI](https://cloud.google.com/sdk/docs/install) | Manages GCP resources | `brew install google-cloud-sdk` |
| [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.9 | Provisions infrastructure | `brew install terraform` |
| [git](https://git-scm.com/) | Version control | pre-installed on most systems |
| [Node.js](https://nodejs.org/) ≥ 20 | Generates frontend lock file | `brew install node` |
| [gh CLI](https://cli.github.com/) | Creates the deployment repository (optional) | `brew install gh` |

Authenticate gcloud before running the wizard:

```bash
gcloud auth login
gcloud auth application-default login
```

### Google Cloud

Create **two GCP projects** with billing enabled — one for dev and one for prod. Note the project IDs and project numbers for both.

### Domains

Prepare two custom domains (or four subdomains) — one pair for dev, one pair for prod:

| Environment | Frontend | Backend |
|---|---|---|
| Dev | `dev.example.com` | `api-dev.example.com` |
| Prod | `app.example.com` | `api.example.com` |

---

## Installation

### 1. Configure deploy.config.json

Edit `deploy.config.json` at the repository root and replace all placeholder values with your actual project IDs, GitHub info, and custom domains:

```json
{
  "region": {
    "default": "asia-northeast1",
    "storage": "ASIA-NORTHEAST1"
  },
  "dev": {
    "project_id": "your-dev-project-id",
    "project_number": "123456789012"
  },
  "prod": {
    "project_id": "your-prod-project-id",
    "project_number": "234567890123"
  },
  "github": {
    "owner": "your-github-username",
    "name": "your-deployment-repo-name"
  },
  "domains": {
    "dev": {
      "frontend": "dev.example.com",
      "backend": "api-dev.example.com"
    },
    "prod": {
      "frontend": "app.example.com",
      "backend": "api.example.com"
    }
  }
}
```

### 2. Run the install wizard

Open Claude Code in this repository and run:

```
/install
```

The wizard will guide you through the following steps:

1. Validate your configuration
2. Enable required GCP APIs in both projects
3. Create a GitHub deployment repository
4. Connect the Cloud Build GitHub App to both GCP projects
5. Run Terraform to provision all infrastructure (GCS state bucket, Terraform SA, Artifact Registry, Cloud Build triggers, IAM)
6. Trigger the first deployment to Cloud Run (dev and prod)
7. Enable custom domain mappings
8. Guide you through DNS record setup

**What the wizard creates in each GCP project:**

- GCS bucket for Terraform state
- Terraform service account with owner role
- Artifact Registry repository for Docker images
- Cloud Build triggers for backend deploy, frontend deploy, terraform plan, terraform apply
- IAM service accounts for builders and runners
- Cloud Run services (`backend-app`, `frontend-app`)
- Cloud Run domain mappings for your custom domains

> **Note:** The wizard makes real changes to GitHub and Google Cloud. Review the confirmation prompts carefully before proceeding.

---

## Uninstallation

To remove all GCP resources and stop billing, run:

```
/uninstall
```

The wizard will:

1. Show you exactly what will be deleted and ask for confirmation
2. Delete Cloud Run services (dev and prod)
3. Delete Artifact Registry repositories and all Docker images
4. Remove Terraform lifecycle restrictions that protect state resources
5. Migrate Terraform state from GCS to local
6. Delete GCS state buckets
7. Run `terraform destroy` to remove all remaining resources (triggers, IAM, service accounts, APIs)

**What is NOT deleted:**
- The GCP projects themselves
- The GitHub deployment repository (you can delete it manually)
- DNS records (you need to remove them from your DNS provider)

---

## Development

After installation, work directly in the **deployment repository** (not this template).

### Local development

**Backend:**

```bash
cd backend
uv sync
uv run python src/main.py   # runs at http://localhost:8080
```

**Frontend:**

```bash
cd frontend
npm install
npm run dev                  # runs at http://localhost:5173
```

### CI/CD workflow

| Action | Trigger | Effect |
|---|---|---|
| Push to `main` (backend changed) | `backend/**/*` | Build and deploy backend to dev |
| Push to `main` (frontend changed) | `frontend/**/*` | Build and deploy frontend to dev |
| Push to `main` (infra changed) | `infra/**/*` | `terraform apply` on dev |
| PR targeting `main` (infra changed) | `infra/**/*` | `terraform plan` on dev |
| Push to `release` | same as above | Same actions on prod |

To release to prod, merge `main` into `release` and push:

```bash
git checkout release
git merge main
git push origin release
```

---

## Tested with

Claude Sonnet 4.6 (`claude-sonnet-4-6`)
