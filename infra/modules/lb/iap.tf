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

# IAP forwards requests to Cloud Run through the load balancer using its own
# service agent, which must hold roles/run.invoker on each service. The service
# agent is provisioned out of band (`gcloud beta services identity create
# --service=iap.googleapis.com`); here we reference its email directly because
# google_project_service_identity requires the google-beta provider.
#
# These bindings are gated on grant_iap_invoker because the Cloud Run services
# are created by Cloud Build (not Terraform) and do not exist during the initial
# install applies. See the grant_iap_invoker variable for the bootstrap sequence.
locals {
  iap_service_agent = "serviceAccount:service-${var.project.number}@gcp-sa-iap.iam.gserviceaccount.com"
}

resource "google_cloud_run_v2_service_iam_member" "iap_invoker_frontend" {
  count    = var.enable_iap && var.grant_iap_invoker ? 1 : 0
  project  = var.project.id
  location = var.region
  name     = var.frontend_service
  role     = "roles/run.invoker"
  member   = local.iap_service_agent
}

resource "google_cloud_run_v2_service_iam_member" "iap_invoker_backend" {
  count    = var.enable_iap && var.grant_iap_invoker ? 1 : 0
  project  = var.project.id
  location = var.region
  name     = var.backend_service
  role     = "roles/run.invoker"
  member   = local.iap_service_agent
}
