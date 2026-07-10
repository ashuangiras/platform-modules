output "container_id" {
  description = "Docker container ID."
  value       = docker_container.consul.id
}

output "container_name" {
  description = "Container name, usable as a hostname on the Docker network."
  value       = docker_container.consul.name
}

output "http_address" {
  description = "Consul HTTP API / UI address from the host."
  value       = "http://localhost:${var.http_port}"
}

output "http_address_internal" {
  description = "Consul HTTP API address reachable from other containers on the same Docker network."
  value       = "http://${var.container_name}:8500"
}

output "dns_address" {
  description = "Consul DNS address reachable from the host."
  value       = "127.0.0.1:${var.dns_port}"
}

output "datacenter" {
  description = "Consul datacenter name."
  value       = var.datacenter
}
