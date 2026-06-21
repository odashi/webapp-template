resource "google_artifact_registry_repository" "images" {
  project       = var.project.id
  location      = var.region.default
  repository_id = "images"
  description   = "Container images"
  format        = "DOCKER"
}
