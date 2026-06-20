resource "google_cloud_run_domain_mapping" "app" {
  count    = var.enable_domain_mapping ? 1 : 0
  location = var.region.default
  name     = var.domain

  metadata {
    namespace = var.project.id
  }

  spec {
    route_name = "${var.prefix}-app"
  }
}
