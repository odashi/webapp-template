# Static IP for the HTTPS load balancer.
resource "google_compute_global_address" "default" {
  project = var.project.id
  name    = "lb"
}

# Google-managed SSL certificate for the frontend domain.
resource "google_compute_managed_ssl_certificate" "default" {
  project = var.project.id
  name    = "ssl"

  managed {
    domains = [var.frontend_domain]
  }
}

# Serverless NEG pointing to the frontend Cloud Run service.
resource "google_compute_region_network_endpoint_group" "frontend" {
  project               = var.project.id
  name                  = "neg-frontend"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = var.frontend_service
  }
}

# Serverless NEG pointing to the backend Cloud Run service.
resource "google_compute_region_network_endpoint_group" "backend" {
  project               = var.project.id
  name                  = "neg-backend"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = var.backend_service
  }
}

# LB backend service for the frontend Cloud Run service.
resource "google_compute_backend_service" "frontend" {
  project               = var.project.id
  name                  = "bs-frontend"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.frontend.id
  }

  dynamic "iap" {
    for_each = var.enable_iap ? [1] : []
    content {
      oauth2_client_id     = var.oauth2_client_id
      oauth2_client_secret = var.oauth2_client_secret
    }
  }
}

# LB backend service for the backend Cloud Run service.
resource "google_compute_backend_service" "backend_api" {
  project               = var.project.id
  name                  = "bs-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.backend.id
  }

  dynamic "iap" {
    for_each = var.enable_iap ? [1] : []
    content {
      oauth2_client_id     = var.oauth2_client_id
      oauth2_client_secret = var.oauth2_client_secret
    }
  }
}

# URL map: /api/* → backend (strip /api prefix), everything else → frontend.
resource "google_compute_url_map" "default" {
  project         = var.project.id
  name            = "url-map"
  default_service = google_compute_backend_service.frontend.id

  host_rule {
    hosts        = [var.frontend_domain]
    path_matcher = "paths"
  }

  path_matcher {
    name            = "paths"
    default_service = google_compute_backend_service.frontend.id

    path_rule {
      paths   = ["/api", "/api/", "/api/*"]
      service = google_compute_backend_service.backend_api.id

      route_action {
        url_rewrite {
          path_prefix_rewrite = "/"
        }
      }
    }
  }
}

# HTTP → HTTPS redirect URL map.
resource "google_compute_url_map" "http_redirect" {
  project = var.project.id
  name    = "http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# HTTPS proxy.
resource "google_compute_target_https_proxy" "default" {
  project          = var.project.id
  name             = "https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

# HTTP proxy (redirect only).
resource "google_compute_target_http_proxy" "default" {
  project = var.project.id
  name    = "http-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

# Forwarding rule: HTTPS (443) → HTTPS proxy.
resource "google_compute_global_forwarding_rule" "https" {
  project               = var.project.id
  name                  = "https"
  target                = google_compute_target_https_proxy.default.id
  port_range            = "443"
  ip_address            = google_compute_global_address.default.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Forwarding rule: HTTP (80) → HTTP proxy (redirect to HTTPS).
resource "google_compute_global_forwarding_rule" "http" {
  project               = var.project.id
  name                  = "http"
  target                = google_compute_target_http_proxy.default.id
  port_range            = "80"
  ip_address            = google_compute_global_address.default.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
