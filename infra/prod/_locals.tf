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

  # TODO: Replace with your prod GCP project values.
  project = {
    id     = "my-prod-project-id"
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

  # Release: deploy prod on every push to release.
  branch = "release"

  # TODO: Replace with your prod custom domains.
  domains = {
    frontend = "app.example.com"
    backend  = "api.example.com"
  }
}
