output "container_id" {
  description = "Docker container ID."
  value       = docker_container.prometheus.id
}

output "container_name" {
  description = "Container name, usable as a hostname on the Docker network."
  value       = docker_container.prometheus.name
}

output "http_address" {
  description = "Prometheus HTTP address from the host."
  value       = "http://localhost:${var.http_port}"
}

output "http_address_internal" {
  description = "Prometheus HTTP address from containers on the same Docker network."
  value       = "http://${var.container_name}:9090"
}

output "health_endpoint" {
  description = "Health check URL (OBS-001). Returns HTTP 200 when Prometheus is ready."
  value       = "http://localhost:${var.http_port}/-/healthy"
}
