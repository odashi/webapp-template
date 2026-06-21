# IAP OAuth consent screen brand (one per project).
# If the project already has an IAP brand (e.g., created via Console), import it:
#   terraform import module.lb.google_iap_brand.default[0] projects/PROJECT_ID/brands/BRAND_ID
resource "google_iap_brand" "default" {
  count             = var.enable_iap ? 1 : 0
  project           = var.project.id
  support_email     = var.support_email
  application_title = "Application"
}

# IAP OAuth 2.0 client.
resource "google_iap_client" "default" {
  count        = var.enable_iap ? 1 : 0
  display_name = "IAP"
  brand        = google_iap_brand.default[0].name
}

# Grant allowed members access to the frontend via IAP.
resource "google_iap_web_backend_service_iam_binding" "frontend" {
  count               = var.enable_iap ? 1 : 0
  project             = var.project.id
  web_backend_service = google_compute_backend_service.frontend.name
  role                = "roles/iap.httpsResourceAccessor"
  members             = var.allowed_members
}

# Grant allowed members access to the backend via IAP.
resource "google_iap_web_backend_service_iam_binding" "backend_api" {
  count               = var.enable_iap ? 1 : 0
  project             = var.project.id
  web_backend_service = google_compute_backend_service.backend_api.name
  role                = "roles/iap.httpsResourceAccessor"
  members             = var.allowed_members
}
