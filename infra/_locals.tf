locals {
  config_root_dir = "./infra"

  enabled_services = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
  ]

  # TODO: Replace with your GCP project values.
  project = {
    id     = "my-project-id"
    number = "000000000000"
  }

  region = {
    default         = "asia-northeast1"
    storage_default = "ASIA-NORTHEAST1"
  }

  # TODO: Replace with your GitHub repository.
  github_repository = {
    owner = "my-github-owner"
    name  = "my-repo-name"
  }

  # TODO: Replace with your custom domains for each environment.
  domains = {
    dev = {
      frontend = "dev.example.com"
      backend  = "api-dev.example.com"
    }
    prod = {
      frontend = "app.example.com"
      backend  = "api.example.com"
    }
  }
}
