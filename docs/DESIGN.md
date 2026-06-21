# Design Principles

Architectural decisions and rules for this template. Read this document before making changes to the frontend, backend, or infrastructure. If you change the architecture, update this document.

Agents should consult this document when adding features, modifying modules, changing CI/CD behaviour, or deciding how to structure new code.

---

## Top-Level Principles

### Template clarity over cleverness

Placeholder values use the verbose `[[[json.key.path]]]` format so substitution points are immediately visible in diffs and grep output. Don't adopt shorter formats or implicit conventions — the template is read by both humans and agents unfamiliar with the codebase.

### Complete environment isolation

Dev and prod are separate GCP projects with no shared resources: separate state buckets, service accounts, Artifact Registry repositories, Cloud Run services, and load balancers. Never add cross-project dependencies. The isolation allows destroying one environment without affecting the other.

### Single-domain architecture

Each environment exposes exactly one public domain. The HTTPS load balancer routes `/api/*` to the backend (stripping the `/api` prefix) and everything else to the frontend. No separate backend-facing domain is created or needed. Keep this routing model; don't introduce per-service subdomains.

### Infrastructure as code

All GCP resources are Terraform-managed. Never create resources manually in the Console without immediately importing them into Terraform state. Untracked resources are invisible to `terraform destroy` and create silent drift.

### Agent-driven operations

`/install`, `/uninstall`, and `/feedback` are Claude Code skills, not shell scripts. They can ask clarifying questions, recover from errors interactively, and write detailed session logs. Don't convert them to bash scripts — the interactivity and logging are load-bearing.

### Logs record everything verbatim

Wizard session logs capture every command with full stdout/stderr — never truncated or summarised. `/feedback` uses the raw output to file accurate bug reports. Summaries lose the diagnostic signal.

---

## Frontend

**Stack:** React 19 + TypeScript + Vite + nginx (static file server)

### Build-time configuration only

`VITE_API_URL` is a Docker `ARG` baked into the image at build time via `--build-arg`. There are no runtime environment variables in the frontend container. New configuration values must be build ARGs passed as Cloud Build substitutions (`_VAR_NAME` in the trigger, `--build-arg VAR=$_VAR` in the YAML).

### Strict TypeScript

`tsconfig.app.json` enables `strict: true`, `noUnusedLocals`, and `noUnusedParameters`. Don't weaken these settings. The template establishes the minimum viable strictness; real applications should not relax it.

### API calls via same-domain `/api/` path

In production the frontend calls `https://<FRONTEND_DOMAIN>/api/<endpoint>`. The load balancer strips `/api` and forwards to the backend Cloud Run service. Never hardcode a separate backend domain in frontend code — the LB routing is the contract.

### No auth logic in the frontend

IAP authenticates users at the load balancer before traffic reaches Cloud Run. The frontend implements no login flows, token handling, or auth headers. If the backend needs to identify the caller, it reads the `X-Goog-Authenticated-User-*` headers that IAP injects.

### Environment files are for local development only

`envs/.env.development` sets `VITE_API_URL=http://localhost:8080` for the local Vite dev server only. Vite does not load `.env.development` during `vite build` (production mode). Don't add GCP-environment values to `.env` files.

---

## Backend

**Stack:** Python 3.13 + FastAPI + uvicorn, managed with uv

### Stateless service

Cloud Run scales horizontally and restarts instances without notice. Never use local filesystem state, in-process caches that must survive restarts, or sticky sessions. All persistent state belongs in external storage (Cloud SQL, Firestore, GCS, etc.).

### Configuration via pydantic-settings

All runtime configuration is typed and read through the `Environment` class in `environment.py` (backed by `pydantic-settings`). Add new values there with typed fields and defaults. Don't read `os.environ` directly elsewhere.

### CORS origin set at deploy time

`CORS_ORIGIN` is injected by Cloud Build as `https://${_FRONTEND_DOMAIN}`. The default in `environment.py` (`http://localhost:5173`) is for local dev only. Don't hardcode production domains in Python source.

### Internal ingress only

Cloud Run services deploy with `--ingress=internal-and-cloud-load-balancing`. They accept traffic only from the load balancer and internal GCP services. `--ingress=all` must never appear in production — the load balancer is the only intended public entry point.

### Health endpoint required

`GET /health` must return `{"status": "ok"}` with HTTP 200. Cloud Run uses this path for health checks. Don't remove it or change its path.

### API docs disabled in production

`FastAPI(docs_url=None, openapi_url=None, redoc_url=None)` disables Swagger UI and OpenAPI schema exposure. Enable them only in local development.

---

## Infrastructure

**Stack:** Terraform + Cloud Build + Cloud Run + HTTPS Load Balancer + IAP

### Module boundaries

Each Terraform module owns one concern. Don't merge modules or let a module reach into another's resources.

| Module | Owns |
|---|---|
| `terraform/` | Terraform CI/CD: state bucket, Terraform SA, plan/apply Cloud Build triggers |
| `common/` | Shared image storage: Artifact Registry repository |
| `service/` | Application CI/CD: deploy Cloud Build trigger, builder/runner IAM service accounts |
| `lb/` | Traffic and auth: HTTPS load balancer, SSL certificate, URL routing, IAP OAuth |

### `_locals.tf` is the single source of truth per environment

All environment-specific values (project IDs, region, domains, branch, IAP config) live in `_locals.tf`. `main.tf` only wires locals into module inputs. Never hardcode environment values directly in `main.tf`.

### `prevent_destroy` on critical resources

GCS state bucket, Terraform SA, its `roles/owner` binding, and API enablements carry `lifecycle { prevent_destroy = true }`. This prevents accidental deletion during normal `terraform destroy` operations. `/uninstall` removes these guards explicitly as the first teardown step.

### Two-phase GCS backend bootstrap

`backend "gcs"` starts commented out in `main.tf`. The first `terraform apply` creates the GCS bucket using local state; the wizard then uncomments the block and runs `terraform init -migrate-state`. Don't pre-populate the backend block — it will fail if the bucket doesn't exist yet.

### 1st-gen Cloud Build triggers only

All triggers use `google_cloudbuild_trigger` with a `github` block (1st gen). 2nd-gen resources (`google_cloudbuild_v2_trigger`) require a different GitHub App connection flow and are not used. Don't mix trigger generations.

### Hardcoded resource names

Cloud Run service names (`backend-app`, `frontend-app`), the AR repository (`images`), and load balancer resource names (`lb`, `ssl`, `url-map`, etc.) are hardcoded strings. They don't need to be configurable. Keeping them constant makes the `/uninstall` wizard's `gcloud` deletion commands reliable without requiring Terraform output lookups.

### Trunk-based CI/CD

`main` branch deploys to dev; `release` branch deploys to prod. Don't add intermediate branches or additional environments to the template. If a staging environment is needed, add a third GCP project following the same module structure.

---

## Documentation

### Document ownership

| Document | Audience | Content |
|---|---|---|
| `README.md` | End users | Prerequisites, installation walkthrough, architecture overview, CI/CD reference |
| `CLAUDE.md` | Claude agents | Operational reference: repository model, placeholder files, Terraform architecture, skill descriptions, implementation quirks |
| `docs/DESIGN.md` | Contributors and agents | Design principles: rationale behind architectural decisions, rules to follow when extending the template |

### When to update each document

**`docs/DESIGN.md`** — update when:
- A new architectural constraint is established
- An existing principle is changed or relaxed
- A new layer or module is added

Don't record implementation details here (file names, variable names, command syntax). Those belong in `CLAUDE.md`.

**`CLAUDE.md`** — update when:
- A placeholder file is added or renamed
- The Terraform architecture changes (new module, renamed file, new quirk)
- A wizard skill's behaviour changes
- An implementation detail is discovered that agents need to know to avoid mistakes

**`README.md`** — update when:
- Prerequisites change
- The installation steps change
- The architecture visible to end users changes (new domain, new service, etc.)

### Principle of separation

`CLAUDE.md` answers *what* and *where* (where are the files, what do the placeholders look like, what does each module contain). `docs/DESIGN.md` answers *why* (why is it structured this way, what must not change, what would break the design). Keep them separate — mixing the two makes both harder to scan.
