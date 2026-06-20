locals {
  # Path to shared infra modules in the repository (for Cloud Build YAML paths).
  infra_dir = "./infra"
  # Path to this Terraform root (passed as -chdir to Cloud Build terraform runs).
  env_dir = "./infra/prod"

  enabled_services = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
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
    backend  = "[[[domains.prod.backend]]]"
  }

  # Set to true after Cloud Run services are deployed to enable domain mappings.
  enable_domain_mapping = false
}
