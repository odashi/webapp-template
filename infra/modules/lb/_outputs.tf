output "lb_ip_address" {
  value       = google_compute_global_address.default.address
  description = "Static IP of the load balancer. Create an A record for your frontend domain pointing to this IP."
}
