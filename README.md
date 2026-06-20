# Webapp Template

A full-stack web application template with automated CI/CD on Google Cloud Platform.

## Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 19, TypeScript, Vite |
| Backend | Python 3.13, FastAPI, uvicorn |
| Infrastructure | Terraform, Google Cloud Run, Artifact Registry |
| CI/CD | Google Cloud Build (triggered by GitHub pushes) |

## Repository structure

```
webapp-template/
├── frontend/       # React + TypeScript app (served via nginx on Cloud Run)
├── backend/        # FastAPI app (Python, managed with uv)
└── infra/          # Terraform configuration for GCP resources
```

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for setup and deployment instructions.
