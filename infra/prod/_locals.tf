locals {
  # Path to shared infra modules in the repository (for Cloud Build YAML paths).
  infra_dir = "./infra"
  # Path to this Terraform root (passed as -chdir to Cloud Build terraform runs).
  env_dir = "./infra/prod"

  enabled_services = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iap.googleapis.com",
    "run.googleapis.com",
  ]

  project = {
    id     = "[[[prod.project_id]]]"
    number = "[[[prod.project_number]]]"
  }

  region = {
    default         = "[[[region.default]]]"
    storage_default = "[[[region.storage]]]"
  }

  github_repository = {
    owner = "[[[github.owner]]]"
    name  = "[[[github.name]]]"
  }

  # Release: deploy prod on every push to release.
  branch = "release"

  domains = {
    frontend = "[[[domains.prod.frontend]]]"
  }

  # Backend API URL: always served at /api on the frontend domain via the load balancer.
  api_url = "https://${local.domains.frontend}/api"

  # IAP is enabled by default so prod is inaccessible at launch.
  # Add members to iap_allowed_members to grant access before public launch.
  # Set enable_iap = false to open prod to the public (removes authentication entirely).
  enable_iap          = true
  iap_allowed_members = [
    # Add members here to grant access before public launch:
    # "user:alice@example.com",
    # "group:launch-team@example.com",
  ]
}
