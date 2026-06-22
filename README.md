# Webapp Template

One Claude Code command deploys a full-stack web application to Google Cloud Platform with separate dev and prod environments, automated CI/CD, and custom domains.

## What you get

- **Two isolated GCP environments** (dev and prod) with independent Cloud Run services, Cloud Build pipelines, Artifact Registry repositories, IAM, and Terraform state
- **Automatic deployments**: push to `main` in the deployment repo → dev; push to `release` → prod
- **Custom domains** with HTTPS load balancer and auto-provisioned Google-managed SSL certificates
- **Infrastructure as code**: every GCP resource managed by Terraform
- **IAP-protected environments**: dev is protected by Identity-Aware Proxy by default; access is restricted to listed members

## Stack

| Layer | Technology |
|---|---|
| Frontend | React 19, TypeScript, Vite — served via nginx on Cloud Run |
| Backend | Python 3.13, FastAPI, uvicorn — on Cloud Run |
| Infrastructure | Terraform, Cloud Run, Artifact Registry, Cloud Build |
| Package managers | npm (frontend), uv (backend) |

## Architecture

```
webapp-template/        ← this repository (always keeps placeholder values on main)
├── frontend/           # React + TypeScript application
├── backend/            # FastAPI application (Python, uv)
├── infra/
│   ├── dev/            # Terraform root for dev GCP project
│   ├── prod/           # Terraform root for prod GCP project
│   └── modules/        # Shared Terraform modules (terraform, common, service, lb)
└── install.json        # Fill this in before running /install
```

This is a **template repository**. Your real configuration (project IDs, domains, GitHub repo) lives on a local `install` branch and is pushed to a separate **deployment repository** created by `/install`. The template always keeps placeholder values on `main` so template improvements can be pulled in cleanly.

**Deployment flow:**

```
install (local)
  └─ push as main ──→ deployment repo main ──→ Cloud Build ──→ dev Cloud Run
  └─ push as release → deployment repo release → Cloud Build ──→ prod Cloud Run
```

---

## Prerequisites

### Tools

| Tool | Required | Purpose |
|---|---|---|
| [Claude Code](https://claude.ai/code) | Yes | Runs the install / uninstall / feedback wizards |
| [gcloud CLI](https://cloud.google.com/sdk/docs/install) | Yes | Enable GCP APIs, manage Cloud Build triggers |
| [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.9 | Yes | Provision GCP infrastructure |
| [git](https://git-scm.com/) | Yes | Manage branches and push to deployment repo |
| [Node.js](https://nodejs.org/) ≥ 20 | Yes | Generate `package-lock.json` for frontend Docker build |
| [gh CLI](https://cli.github.com/) | Optional | Create the deployment repository automatically |

Authenticate gcloud before running the wizard:

```bash
gcloud auth login
gcloud auth application-default login
```

### Google Cloud

Create **two GCP projects** with billing enabled — one for dev, one for prod. Note the project ID and 12-digit project number for each.

### Custom domains

Prepare two subdomains — one for dev, one for prod:

| Environment | Frontend |
|---|---|
| Dev | `dev.example.com` |
| Prod | `app.example.com` |

The backend is served at `/api/` on the same frontend domain via the HTTPS load balancer. No separate backend domain is needed.

---

## Installation

### 1. Fill in install.json

Edit `install.json` and replace every `[[[...]]]` placeholder with your actual values:

```json
{
  "region": {
    "default": "asia-northeast1",
    "storage": "ASIA-NORTHEAST1"
  },
  "dev": {
    "project_id": "my-app-dev",
    "project_number": "123456789012"
  },
  "prod": {
    "project_id": "my-app-prod",
    "project_number": "234567890123"
  },
  "github": {
    "owner": "my-github-username",
    "name": "my-app"
  },
  "domains": {
    "dev": {
      "frontend": "dev.example.com"
    },
    "prod": {
      "frontend": "app.example.com"
    }
  }
}
```

### 2. Run the install wizard

Open Claude Code in this directory and run:

```
/install
```

The wizard explains what it will do, confirms with you at each phase, and handles everything below automatically. End-to-end it takes about 20–30 minutes.

**What the wizard creates in each GCP project:**

| Resource | Purpose |
|---|---|
| GCS bucket (`PROJECT_ID-terraform`) | Terraform remote state |
| Terraform service account | Cloud Build infrastructure management |
| Artifact Registry repository (`images`) | Docker image storage |
| Cloud Build trigger: `backend-deploy` | Deploys backend on `backend/**/*` push |
| Cloud Build trigger: `frontend-deploy` | Deploys frontend on `frontend/**/*` push |
| Cloud Build trigger: `terraform-apply` | Applies infra on push (env dir or `infra/modules/**/*`) |
| Cloud Build trigger: `terraform-plan` | Plans infra on PR targeting the branch (same file filter) |
| Cloud Run service: `backend-app` | Running backend |
| Cloud Run service: `frontend-app` | Running frontend |
| HTTPS load balancer | Routes `/api/*` to backend, `/*` to frontend; auto-provisioned SSL |
| IAP | Protects the environment via OAuth; dev restricts access to listed members by default |
| Secret Manager secrets | Stores IAP OAuth client credentials |

> **Note:** The wizard makes real changes to GitHub and Google Cloud. Read each confirmation prompt before proceeding.

---

## Development

After installation, work in the **deployment repository** created by `/install`, not this template.

### Local development

**Backend** (runs at http://localhost:8080):

```bash
cd backend
uv sync
uv run python src/main.py
```

**Frontend** (runs at http://localhost:5173, calls backend at http://localhost:8080):

```bash
cd frontend
npm install
npm run dev
```

### CI/CD

| Files changed | Branch | Effect |
|---|---|---|
| `backend/**/*` | `main` | Build and deploy backend to **dev** |
| `frontend/**/*` | `main` | Build and deploy frontend to **dev** |
| `infra/dev/**/*` or `infra/modules/**/*` | `main` | `terraform apply` on **dev** |
| `infra/dev/**/*` or `infra/modules/**/*` | PR → `main` | `terraform plan` on **dev** |
| `backend/**/*` or `frontend/**/*` | `release` | Build and deploy to **prod** |
| `infra/prod/**/*` or `infra/modules/**/*` | `release` | `terraform apply` on **prod** |

Changes to `*.md` files never trigger builds.

### Release to prod

```bash
git checkout release
git merge main
git push origin release     # triggers prod Cloud Build
```

---

## Demo application

The template ships a working "character counter" app to confirm the deployment is healthy. Replace it with your application.

- **Backend** (`backend/src/main.py`): `GET /health` → `{"status": "ok"}`; `POST /count` → `{"count": N}` (character count of the request body text)
- **Frontend** (`frontend/src/App.tsx`): a textarea and button that calls the backend and displays the count

To replace the demo app, update the source under `frontend/src/` and `backend/src/`. The Dockerfiles, Cloud Build YAMLs, and Terraform configuration require no changes for typical web applications.

---

## Uninstall

To remove all GCP resources and stop billing:

```
/uninstall
```

The wizard will:

1. Show exactly what will be deleted and require explicit confirmation
2. Remove Terraform `prevent_destroy` guards
3. Delete Cloud Run services and Artifact Registry images (which Terraform does not manage)
4. Migrate Terraform state from GCS to local, then delete the GCS buckets
5. Run `terraform destroy` to remove triggers, IAM accounts, and API enablements
6. Verify all resources have been removed

**Not deleted by the wizard:**
- The GCP projects themselves
- The GitHub deployment repository (delete it manually if desired)
- DNS records at your domain provider

---

## Feedback

If you hit a problem or have a suggestion, the `/feedback` skill reads your wizard session logs and files GitHub issues against this template repository:

```
/feedback
```

Wizard sessions are automatically logged to `logs/install-TIMESTAMP.md` and `logs/uninstall-TIMESTAMP.md` (this directory is gitignored). The skill identifies template-side issues (not your environment or GCP configuration), drafts GitHub issues, and asks for your approval before filing each one.

---

## Tested with

Claude Sonnet 4.6 (`claude-sonnet-4-6`)
