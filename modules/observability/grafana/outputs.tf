output "container_id" {
  description = "Docker container ID."
  value       = docker_container.grafana.id
}

output "container_name" {
  description = "Container name, usable as a hostname on the Docker network."
  value       = docker_container.grafana.name
}

output "http_address" {
  description = "Grafana UI address from the host."
  value       = "http://localhost:${var.http_port}"
}

output "http_address_internal" {
  description = "Grafana address from containers on the same Docker network."
  value       = "http://${var.container_name}:3000"
}

output "health_endpoint" {
  description = "Health check URL (OBS-001). Returns HTTP 200 with {\"database\":\"ok\"} when ready."
  value       = "http://localhost:${var.http_port}/api/health"
}
