output "container_name" {
  description = "PostgreSQL container hostname on the Docker network."
  value       = docker_container.postgresql.name
}

output "host" {
  description = "PostgreSQL host from the Docker network (use for service-to-service connections)."
  value       = docker_container.postgresql.name
}

output "host_address" {
  description = "PostgreSQL address from the host machine."
  value       = "localhost"
}

output "port" {
  description = "PostgreSQL port."
  value       = var.port
}

output "superuser_username" {
  description = "PostgreSQL superuser username."
  value       = "postgres"
}

output "connections" {
  description = "Per-service connection details map. Sensitive — write to Vault via vault_kv_secret_v2 in the calling module."
  sensitive   = true
  value = {
    for name, db in var.databases : name => {
      username = name
      password = db.password
      database = name
      host     = docker_container.postgresql.name
      port     = tostring(var.port)
      url      = "postgresql://${name}:${db.password}@${docker_container.postgresql.name}:${var.port}/${name}"
    }
  }
}
