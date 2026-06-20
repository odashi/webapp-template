variable "config_root_dir" {
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

variable "repository" {
  type = object({
    owner = string
    name  = string
  })
}
