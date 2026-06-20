resource "google_project_service" "common" {
  for_each = toset(local.enabled_services)
  service  = each.key
  lifecycle {
    prevent_destroy = true
  }
}
