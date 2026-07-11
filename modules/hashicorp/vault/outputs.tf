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

output "root_token" {
  description = "Vault root token. Written to keys_path on first init. Sensitive."
  value       = fileexists(pathexpand(var.keys_path)) ? jsondecode(file(pathexpand(var.keys_path)))["root_token"] : null
  sensitive   = true
  depends_on  = [null_resource.vault_init_unseal]
}

output "keys_path" {
  description = "Path to the file containing Vault unseal keys and root token."
  value       = pathexpand(var.keys_path)
}
