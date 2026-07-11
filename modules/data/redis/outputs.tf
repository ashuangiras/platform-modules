output "container_name" {
  description = "Redis container hostname on the Docker network."
  value       = docker_container.redis.name
}

output "host" {
  description = "Redis host for service-to-service connections (Docker network hostname)."
  value       = docker_container.redis.name
}

output "port" {
  description = "Redis port."
  value       = var.port
}

output "connections" {
  description = "Per-service connection details. Sensitive — write to Vault via vault_kv_secret_v2."
  sensitive   = true
  value = {
    for name, u in var.acl_users : name => {
      username = name
      password = u.password
      host     = docker_container.redis.name
      port     = tostring(var.port)
      url      = "redis://${name}:${u.password}@${docker_container.redis.name}:${var.port}"
    }
  }
}
