output "container_id" {
  description = "Docker container ID."
  value       = docker_container.vault.id
}

output "container_name" {
  description = "Container name, usable as a hostname on the Docker network."
  value       = docker_container.vault.name
}

output "api_address" {
  description = "Vault API address reachable from the host."
  value       = "http://localhost:${var.api_port}"
}

output "api_address_internal" {
  description = "Vault API address reachable from other containers on the same Docker network."
  value       = "http://${var.container_name}:${var.api_port}"
}
