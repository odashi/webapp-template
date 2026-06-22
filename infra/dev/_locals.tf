locals {
  # Path to shared infra modules in the repository (for Cloud Build YAML paths).
  infra_dir = "./infra"
  # Path to this Terraform root (passed as -chdir to Cloud Build terraform runs).
  env_dir = "./infra/dev"

  enabled_services = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iap.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
  ]

  project = {
    id     = "[[[dev.project_id]]]"
    number = "[[[dev.project_number]]]"
  }

  region = {
    default         = "[[[region.default]]]"
    storage_default = "[[[region.storage]]]"
  }

  github_repository = {
    owner = "[[[github.owner]]]"
    name  = "[[[github.name]]]"
  }

  # Trunk: deploy dev on every push to main.
  branch = "main"

  domains = {
    frontend = "[[[domains.dev.frontend]]]"
  }

  # Backend API URL: always served at /api on the frontend domain via the load balancer.
  api_url = "https://${local.domains.frontend}/api"

  # IAP — dev is protected by default; only listed members can access the environment.
  # To open dev to the public, set enable_iap = false.
  enable_iap          = true
  iap_allowed_members = [
    # Add members here to grant access (e.g., "user:alice@example.com"):
  ]
}
