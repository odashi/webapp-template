variable "project" {
  type = object({
    id     = string
    number = string
  })
}

variable "region" {
  type        = string
  description = "GCP region where the Cloud Run services are deployed."
}

variable "frontend_domain" {
  type        = string
  description = "Custom domain for the frontend. The load balancer is configured for this domain."
}

variable "frontend_service" {
  type        = string
  description = "Cloud Run service name for the frontend (e.g., 'frontend-app')."
}

variable "backend_service" {
  type        = string
  description = "Cloud Run service name for the backend (e.g., 'backend-app')."
}

variable "enable_iap" {
  type        = bool
  default     = false
  description = "Whether to enable Identity-Aware Proxy. When false, the load balancer serves traffic without authentication."
}

variable "grant_iap_invoker" {
  type        = bool
  default     = true
  description = <<-EOT
    Whether to grant the IAP service agent roles/run.invoker on the Cloud Run
    services. Only effective when enable_iap = true. Defaults to true so the
    binding is maintained by every steady-state apply. Set to false during the
    initial install applies that run before the Cloud Run services exist (the
    services are created by Cloud Build, not Terraform); re-apply with the
    default true once the services have been deployed.
  EOT
}

variable "oauth2_client_id" {
  type        = string
  default     = ""
  description = "OAuth 2.0 client ID for IAP. Required when enable_iap = true. Create manually in GCP Console (APIs & Services → Credentials)."
  sensitive   = true
}

variable "oauth2_client_secret" {
  type        = string
  default     = ""
  description = "OAuth 2.0 client secret for IAP. Required when enable_iap = true."
  sensitive   = true
}

variable "allowed_members" {
  type        = list(string)
  default     = []
  description = "IAM members who can access both services via IAP (e.g., [\"user:alice@example.com\"]). Only used when enable_iap = true."
}
