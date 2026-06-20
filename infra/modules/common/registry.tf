resource "google_artifact_registry_repository" "images" {
  location      = var.region.default
  repository_id = "images"
  description   = "Container images"
  format        = "DOCKER"
}
