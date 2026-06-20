resource "google_cloudbuild_trigger" "terraform" {
  for_each = toset(["plan", "apply"])

  name        = "terraform-${each.key}"
  description = "terraform ${each.key}"

  github {
    owner = var.repository.owner
    name  = var.repository.name

    dynamic "pull_request" {
      for_each = each.key == "plan" ? [1] : []
      content {
        branch = "^main$"
      }
    }
    dynamic "push" {
      for_each = each.key == "apply" ? [1] : []
      content {
        branch = "^main$"
      }
    }
  }

  service_account = google_service_account.terraform.id
  filename        = "${var.config_root_dir}/modules/terraform/${each.key}.cloudbuild.yaml"
  substitutions = {
    _CHDIR = var.config_root_dir
  }

  included_files = ["infra/**/*"]
  ignored_files  = ["**/*.md"]
}
