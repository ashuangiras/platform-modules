output "server_container_name" {
  description = "Authentik server container name (hostname on the Docker network)."
  value       = docker_container.server.name
}

output "worker_container_name" {
  description = "Authentik worker container name."
  value       = docker_container.worker.name
}

output "http_url" {
  description = "Authentik HTTP URL from the host."
  value       = "http://localhost:${var.http_port}"
}

output "https_url" {
  description = "Authentik HTTPS URL from the host."
  value       = "https://localhost:${var.https_port}"
}

output "internal_url" {
  description = "Authentik URL for containers on the same Docker network (used as OIDC issuer URL)."
  value       = "http://${docker_container.server.name}:9000"
}

output "issuer_url" {
  description = "OIDC issuer URL — use this as the oidc_discovery_url in Vault JWT auth backend and other OIDC consumers."
  value       = "http://localhost:${var.http_port}/application/o"
}
