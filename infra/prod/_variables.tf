variable "oauth2_client_id" {
  type        = string
  default     = ""
  description = "OAuth 2.0 client ID for IAP. Required when enable_iap = true. Pass via -var or terraform.tfvars (gitignored)."
  sensitive   = true
}

variable "oauth2_client_secret" {
  type        = string
  default     = ""
  description = "OAuth 2.0 client secret for IAP. Required when enable_iap = true."
  sensitive   = true
}
