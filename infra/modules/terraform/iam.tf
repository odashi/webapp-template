resource "google_service_account" "terraform" {
  account_id   = "terraform"
  display_name = "Terraform service account"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project_iam_member" "owner" {
  project = var.project.id
  role    = "roles/owner"
  member  = google_service_account.terraform.member

  lifecycle {
    prevent_destroy = true
  }
}
