data "google_cloud_run_service" "app" {
  name     = "${var.prefix}-app"
  location = var.region.default
}

resource "google_cloud_run_domain_mapping" "app" {
  location = var.region.default
  name     = var.domain

  metadata {
    namespace = var.project.id
  }

  spec {
    route_name = data.google_cloud_run_service.app.name
  }
}
