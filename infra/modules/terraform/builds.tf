resource "google_cloudbuild_trigger" "terraform" {
  for_each = toset(["plan", "apply"])

  project     = var.project.id
  name        = "terraform-${each.key}"
  description = "terraform ${each.key}"

  github {
    owner = var.repository.owner
    name  = var.repository.name

    dynamic "pull_request" {
      for_each = each.key == "plan" ? [1] : []
      content {
        branch = "^${var.branch}$"
      }
    }
    dynamic "push" {
      for_each = each.key == "apply" ? [1] : []
      content {
        branch = "^${var.branch}$"
      }
    }
  }

  service_account = google_service_account.terraform.id
  filename        = "${var.infra_dir}/modules/terraform/${each.key}.cloudbuild.yaml"
  substitutions = {
    _CHDIR = var.terraform_chdir
  }

  included_files = ["${var.terraform_chdir}/**/*", "${var.infra_dir}/modules/**/*"]
  ignored_files  = ["**/*.md"]
}
