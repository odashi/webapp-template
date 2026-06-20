variable "infra_dir" {
  type        = string
  description = "Path to the shared infra directory in the repository (for Cloud Build YAML paths)."
}

variable "terraform_chdir" {
  type        = string
  description = "Path to this Terraform root, passed as -chdir in Cloud Build terraform runs."
}

variable "branch" {
  type        = string
  description = "Git branch this environment deploys from (e.g. 'main' for dev, 'release' for prod)."
}

variable "project" {
  type = object({
    id     = string
    number = string
  })
}

variable "region" {
  type = object({
    default         = string
    storage_default = string
  })
}

variable "repository" {
  type = object({
    owner = string
    name  = string
  })
}
