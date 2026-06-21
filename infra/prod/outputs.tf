output "lb_ip_address" {
  value       = module.lb.lb_ip_address
  description = "Static IP of the load balancer. Set an A record for your frontend domain pointing to this IP."
}
