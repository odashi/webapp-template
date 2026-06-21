resource "google_storage_bucket" "terraform" {
  project                     = var.project.id
  name                        = "${var.project.id}-terraform"
  location                    = var.region.storage_default
  uniform_bucket_level_access = true

  lifecycle {
    prevent_destroy = true
  }
}
