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

  # TODO: Replace with your dev GCP project values.
  project = {
    id     = "my-dev-project-id"
    number = "000000000000"
  }

  # TODO: Replace with your GCP region values.
  region = {
    default         = "my-gcp-region"
    storage_default = "MY-STORAGE-REGION"
  }

  # TODO: Replace with your GitHub repository.
  github_repository = {
    owner = "my-github-owner"
    name  = "my-repo-name"
  }

  # Trunk: deploy dev on every push to main.
  branch = "main"

  # TODO: Replace with your dev custom domains.
  domains = {
    frontend = "dev.example.com"
    backend  = "api-dev.example.com"
  }

  # Set to true after Cloud Run services are deployed to enable domain mappings.
  enable_domain_mapping = false
}
