terraform {
  # TODO: Replace with your GCS bucket name for Terraform state.
  backend "gcs" {
    bucket = "my-project-id-terraform"
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
  source = "./modules/terraform"

  depends_on = [google_project_service.common]

  config_root_dir = local.config_root_dir
  project         = local.project
  region          = local.region
  repository      = local.github_repository
}

module "common" {
  source = "./modules/common"

  depends_on = [google_project_service.common]

  region = local.region
}

module "backend_dev" {
  source = "./modules/service"

  depends_on = [google_project_service.common]

  prefix            = "backend-dev"
  service_type      = "backend"
  branch            = "main"
  config_root_dir   = local.config_root_dir
  project           = local.project
  region            = local.region
  domain            = local.domains.dev.backend
  github_repository = local.github_repository
  image_repository  = module.common.image_repository
  extra_substitutions = {
    _FRONTEND_DOMAIN = local.domains.dev.frontend
  }
}

module "frontend_dev" {
  source = "./modules/service"

  depends_on = [google_project_service.common]

  prefix            = "frontend-dev"
  service_type      = "frontend"
  branch            = "main"
  config_root_dir   = local.config_root_dir
  project           = local.project
  region            = local.region
  domain            = local.domains.dev.frontend
  github_repository = local.github_repository
  image_repository  = module.common.image_repository
  extra_substitutions = {
    _VITE_API_URL = "https://${local.domains.dev.backend}"
  }
}

module "backend_prod" {
  source = "./modules/service"

  depends_on = [google_project_service.common]

  prefix            = "backend-prod"
  service_type      = "backend"
  branch            = "release"
  config_root_dir   = local.config_root_dir
  project           = local.project
  region            = local.region
  domain            = local.domains.prod.backend
  github_repository = local.github_repository
  image_repository  = module.common.image_repository
  extra_substitutions = {
    _FRONTEND_DOMAIN = local.domains.prod.frontend
  }
}

module "frontend_prod" {
  source = "./modules/service"

  depends_on = [google_project_service.common]

  prefix            = "frontend-prod"
  service_type      = "frontend"
  branch            = "release"
  config_root_dir   = local.config_root_dir
  project           = local.project
  region            = local.region
  domain            = local.domains.prod.frontend
  github_repository = local.github_repository
  image_repository  = module.common.image_repository
  extra_substitutions = {
    _VITE_API_URL = "https://${local.domains.prod.backend}"
  }
}
