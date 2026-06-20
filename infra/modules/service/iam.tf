resource "google_service_account" "builder" {
  account_id   = "${var.prefix}-builder"
  display_name = "${var.prefix} builder service account"
}

resource "google_service_account" "runner" {
  account_id   = "${var.prefix}-runner"
  display_name = "${var.prefix} runner service account"
}

resource "google_project_iam_member" "builder_log_writer" {
  project = var.project.id
  role    = "roles/logging.logWriter"
  member  = google_service_account.builder.member
}

resource "google_project_iam_member" "builder_run_admin" {
  project = var.project.id
  role    = "roles/run.admin"
  member  = google_service_account.builder.member
}

resource "google_artifact_registry_repository_iam_member" "builder_artifact_writer" {
  project    = var.project.id
  location   = var.region.default
  repository = var.image_repository.name
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.builder.member
}

resource "google_service_account_iam_member" "builder_runner_user" {
  service_account_id = google_service_account.runner.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.builder.member
}
