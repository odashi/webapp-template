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
