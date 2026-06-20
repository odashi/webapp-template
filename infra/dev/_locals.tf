locals {
  # Path to shared infra modules in the repository (for Cloud Build YAML paths).
  infra_dir = "./infra"
  # Path to this Terraform root (passed as -chdir to Cloud Build terraform runs).
  env_dir = "./infra/dev"

  enabled_services = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
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
    backend  = "[[[domains.dev.backend]]]"
  }

  # Set to true after Cloud Run services are deployed to enable domain mappings.
  enable_domain_mapping = false
}
