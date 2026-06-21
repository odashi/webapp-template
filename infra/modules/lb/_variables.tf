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

variable "support_email" {
  type        = string
  default     = ""
  description = "Email shown on the IAP OAuth consent screen. Required when enable_iap = true."
}

variable "allowed_members" {
  type        = list(string)
  default     = []
  description = "IAM members who can access both services via IAP (e.g., [\"user:alice@example.com\"]). Only used when enable_iap = true."
}
