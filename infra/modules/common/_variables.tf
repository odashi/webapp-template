variable "region" {
  type = object({
    default         = string
    storage_default = string
  })
}
