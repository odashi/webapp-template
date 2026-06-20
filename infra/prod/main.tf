terraform {
  # TODO: Replace with your prod GCS bucket name for Terraform state.
  backend "gcs" {
    bucket = "my-prod-project-id-terraform"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.0.0"
    }
  }
}

provider "google" {
  project         = local.project.id
  region          = local.region.default
  request_timeout = "60s"
}

provider "google-beta" {
  project         = local.project.id
  region          = local.region.default
  request_timeout = "60s"
}

module "terraform" {
  source = "../modules/terraform"

  depends_on = [google_project_service.common]

  infra_dir       = local.infra_dir
  terraform_chdir = local.env_dir
  branch          = local.branch
  project         = local.project
  region          = local.region
  repository      = local.github_repository
}

module "common" {
  source = "../modules/common"

  depends_on = [google_project_service.common]

  region = local.region
}

module "backend" {
  source = "../modules/service"

  depends_on = [google_project_service.common]

  prefix          = "backend"
  service_type    = "backend"
  branch          = local.branch
  config_root_dir = local.infra_dir
  project         = local.project
  region          = local.region
  domain          = local.domains.backend
  github_repository = local.github_repository
  image_repository  = module.common.image_repository
  extra_substitutions = {
    _FRONTEND_DOMAIN = local.domains.frontend
  }
}

module "frontend" {
  source = "../modules/service"

  depends_on = [google_project_service.common]

  prefix          = "frontend"
  service_type    = "frontend"
  branch          = local.branch
  config_root_dir = local.infra_dir
  project         = local.project
  region          = local.region
  domain          = local.domains.frontend
  github_repository = local.github_repository
  image_repository  = module.common.image_repository
  extra_substitutions = {
    _VITE_API_URL = "https://${local.domains.backend}"
  }
}
