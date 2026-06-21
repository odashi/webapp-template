resource "google_service_account" "terraform" {
  project      = var.project.id
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

resource "google_service_account_iam_member" "cloudbuild_impersonation" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.project.number}@cloudbuild.gserviceaccount.com"
}
