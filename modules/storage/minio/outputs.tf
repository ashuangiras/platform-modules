output "container_id" {
  description = "Docker container ID."
  value       = docker_container.minio.id
}

output "container_name" {
  description = "Container name, usable as a hostname on the Docker network."
  value       = docker_container.minio.name
}

output "api_endpoint" {
  description = "S3-compatible API endpoint reachable from the host."
  value       = "http://localhost:${var.api_port}"
}

output "console_url" {
  description = "MinIO web console URL reachable from the host."
  value       = "http://localhost:${var.console_port}"
}

output "volume_name" {
  description = "Docker volume name holding persisted MinIO data."
  value       = docker_volume.data.name
}
