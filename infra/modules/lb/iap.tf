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
