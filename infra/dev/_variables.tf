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

variable "grant_iap_invoker" {
  type        = bool
  default     = true
  description = "Grant the IAP service agent roles/run.invoker on the Cloud Run services. Set to false for the install applies that run before the services exist; default true for steady-state applies."
}
