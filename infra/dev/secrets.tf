resource "google_secret_manager_secret" "oauth2_client_id" {
  count     = local.enable_iap ? 1 : 0
  project   = local.project.id
  secret_id = "oauth2-client-id"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "oauth2_client_secret" {
  count     = local.enable_iap ? 1 : 0
  project   = local.project.id
  secret_id = "oauth2-client-secret"

  replication {
    auto {}
  }
}
