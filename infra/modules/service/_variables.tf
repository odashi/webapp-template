variable "prefix" {
  type = string
}

variable "service_type" {
  type        = string
  description = "Service type used to locate the Cloud Build YAML: 'backend' or 'frontend'."
}

variable "branch" {
  type        = string
  description = "Git branch that triggers the Cloud Build deploy (e.g. 'main' for dev, 'release' for prod)."
}

variable "infra_dir" {
  type = string
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

variable "github_repository" {
  type = object({
    owner = string
    name  = string
  })
}

variable "image_repository" {
  type = object({
    name = string
  })
}

variable "extra_substitutions" {
  type    = map(string)
  default = {}
}

