# Webapp Template

## Language

Respond to the user in [[[language]]].

## Overview

Full-stack web application template deployed to Google Cloud Platform via the `/install`, `/uninstall`, and `/feedback` Claude Code skills. See `README.md` for user-facing documentation.

**Stack:** React 19 + TypeScript (Vite, nginx), Python 3.13 + FastAPI (uvicorn), Terraform, Cloud Build, Cloud Run.

## Documentation

| Document | Audience | Purpose |
|---|---|---|
| `README.md` | End users | Prerequisites, installation walkthrough, CI/CD reference |
| `CLAUDE.md` (this file) | Claude agents | Operational reference: repo model, placeholders, module layout, skill behaviour, implementation quirks |
| `docs/DESIGN.md` | Contributors and agents | Design principles: rationale behind architectural decisions, rules to follow when extending the template |

Read `docs/DESIGN.md` before making architectural changes — it records *why* things are structured the way they are. This file (`CLAUDE.md`) records *what* exists and *where* to find it.

## Repository Model

| Remote | What it is |
|---|---|
| `origin` | This template repository — `main` always keeps placeholder values; never fill them in here |
| `app` | Deployment repository — holds real configuration; created by `/install` |

The local `install` branch bridges the two: it carries filled-in configuration values and is pushed to `app` as `main` (and later as `release`). **`install` is never pushed to `origin`.**

## Branch Strategy

| Branch | Remote | Purpose |
|---|---|---|
| `main` | `origin` (template) | Template development — placeholders always intact |
| `install` | local only | Real config values; pushed to `app` only |
| `main` | `app` (deployment) | Triggers dev Cloud Build on every push |
| `release` | `app` (deployment) | Triggers prod Cloud Build on every push |

## Placeholder Format

Unfilled template values use `[[[json.key.path]]]`. The path matches the key in `install.json`.

Files that contain placeholders (on `main`):

| File | Placeholders |
|---|---|
| `install.json` | All values — source of truth |
| `infra/dev/_locals.tf` | dev project, region, GitHub repo, domains |
| `infra/dev/main.tf` | GCS backend bucket name |
| `infra/prod/_locals.tf` | prod project, region, GitHub repo, domains |
| `infra/prod/main.tf` | GCS backend bucket name |

The `/install` wizard substitutes all placeholders on `install` before pushing to the deployment repo.

## Skills

| Skill | Purpose |
|---|---|
| `/install` | Fills placeholders, enables GCP APIs, creates deployment repo, connects Cloud Build GitHub App, runs Terraform for dev + prod, deploys Cloud Run services, configures DNS for HTTPS load balancers |
| `/uninstall` | Removes `prevent_destroy` guards, deletes Cloud Run services and AR images, migrates Terraform state, runs `terraform destroy` for prod then dev, verifies deletion |
| `/feedback` | Reads session logs in `logs/`, identifies template-side issues (not environment issues), drafts GitHub issues, files approved ones to `origin` via `gh` |

The `/install` wizard writes the `## Language` section of this file in Phase 0. The `/uninstall` wizard reads that section to determine its communication language.

## Session Logs

Wizard sessions write detailed logs to `logs/` (gitignored by `.gitignore`):

- `logs/install-YYYYMMDD-HHMMSS.md` — written by `/install`
- `logs/uninstall-YYYYMMDD-HHMMSS.md` — written by `/uninstall`

Each log records every command run with full output, errors, user decisions, and a `## User Feedback` section collected at the end of the session. `/feedback` reads these logs to draft GitHub issues.

## Terraform Architecture

```
infra/
├── dev/
│   ├── _locals.tf      ← all config values for dev (project, region, domains, GitHub, IAP)
│   ├── main.tf         ← GCS backend + calls five modules
│   ├── outputs.tf      ← exposes lb_ip_address
│   └── services.tf     ← enables GCP APIs (prevent_destroy = true)
├── prod/               ← identical structure, prod values
└── modules/
    ├── terraform/      ← GCS state bucket + Terraform SA + plan/apply Cloud Build triggers
    ├── common/         ← Artifact Registry repository
    ├── service/        ← Cloud Build deploy trigger + builder/runner IAM SAs
    │                     (called twice from main.tf: once for backend, once for frontend)
    └── lb/             ← HTTPS load balancer, SSL cert, URL routing (/api → backend), IAP
```

**Key implementation details:**

- **GCS backend bootstrap**: `backend "gcs"` is initially commented out in `main.tf`. `/install` runs `terraform apply` with local state first (creates the GCS bucket), then uncomments the block and migrates state with `terraform init -migrate-state`.
- **Single-domain routing**: the HTTPS load balancer routes `/*` to frontend and `/api/*` to backend (stripping the `/api` prefix). Only one frontend domain is required; no separate backend domain.
- **Cloud Build uses 1st-gen triggers** (`google_cloudbuild_trigger` with `github` block). These require the Cloud Build GitHub App to be manually connected via the GCP Console Triggers page — not the Repositories page (2nd gen).
- **File-path trigger filters**: backend trigger fires on `backend/**/*`; frontend on `frontend/**/*`; terraform triggers fire on `infra/dev/**/*` + `infra/modules/**/*` (dev) and `infra/prod/**/*` + `infra/modules/**/*` (prod). Changing `infra/prod/_locals.tf` on `main` does not trigger dev terraform. All triggers have `ignored_files = ["**/*.md"]`.
- **`prevent_destroy = true`** on: GCS state bucket, Terraform SA, its `roles/owner` IAM binding, and GCP API enablements. `/uninstall` removes these guards before running `terraform destroy`.

## Demo Application

The template ships a "character counter" app to verify the full deployment stack. Replace it with your application.

| File | Description |
|---|---|
| `backend/src/main.py` | FastAPI app: `GET /health` → `{"status":"ok"}`, `POST /count` → `{"count": N}` |
| `backend/src/environment.py` | Pydantic settings; reads `PORT` (default 8080) and `CORS_ORIGIN` from env. Cloud Build sets `CORS_ORIGIN=https://${_FRONTEND_DOMAIN}` at deploy time. |
| `frontend/src/App.tsx` | React form: submits textarea text to the backend, displays character count |
| `frontend/src/api.ts` | Calls `POST /count`; reads `VITE_API_URL` from env (baked into Docker image at build time via `--build-arg`) |
| `frontend/envs/.env.development` | `VITE_API_URL=http://localhost:8080` for local dev |

The frontend API URL (`VITE_API_URL`) is a Docker build ARG set by Cloud Build substitution (`_VITE_API_URL`), not a runtime environment variable.

## Local Development

**Backend** (FastAPI, port 8080):

```bash
cd backend && uv sync && uv run python src/main.py
```

**Frontend** (Vite dev server, port 5173; calls `http://localhost:8080`):

```bash
cd frontend && npm install && npm run dev
```
