resource "google_cloudbuild_trigger" "deploy" {
  project     = var.project.id
  name        = "${var.prefix}-deploy"
  description = "Build trigger to build and deploy ${var.prefix}."

  service_account = google_service_account.builder.id

  github {
    owner = var.github_repository.owner
    name  = var.github_repository.name

    push {
      branch = "^${var.branch}$"
    }
  }

  filename = "${var.infra_dir}/modules/${var.service_type}/cloudbuild.yaml"

  substitutions = merge(
    {
      _PREFIX = var.prefix
      _GAR_ROOT = format(
        "%s-docker.pkg.dev/%s/%s",
        var.region.default,
        var.project.id,
        var.image_repository.name,
      )
      _RUNNER_REGION          = var.region.default
      _RUNNER_SERVICE_ACCOUNT = google_service_account.runner.email
    },
    var.extra_substitutions,
  )

  included_files = ["${var.service_type}/**/*"]
  ignored_files  = ["**/*.md"]
}
