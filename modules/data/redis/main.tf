locals {
  # Build the ACL file content. Each line follows the Redis ACL format:
  # user <name> on ><password> ~<key_prefix> <commands>
  # The 'default' user is disabled to force explicit authentication.
  acl_lines = concat(
    ["user default off"],
    ["user admin on >${var.admin_password} ~* &* +@all"],
    [
      for name, u in var.acl_users :
      "user ${name} on >${u.password} ${u.key_prefix != "" ? "~${u.key_prefix}" : "~*"} &* ${u.commands}"
    ]
  )
  acl_content = join("\n", local.acl_lines)
}

# Write the ACL file to the host before the container starts.
# The container mounts this file read-only so changes require a re-apply + restart.
resource "local_file" "acl" {
  filename        = "${var.config_path}/users.acl"
  content         = local.acl_content
  file_permission = "0600"
}

data "docker_registry_image" "redis" {
  name = "redis:${var.image_tag}"
}

resource "docker_image" "redis" {
  name          = data.docker_registry_image.redis.name
  pull_triggers = [data.docker_registry_image.redis.sha256_digest]
  keep_locally  = true
}

resource "docker_volume" "data" {
  name = "${var.container_name}-data"

  driver = "local"
  driver_opts = {
    type   = "none"
    device = var.data_path
    o      = "bind"
  }
}

resource "docker_volume" "config" {
  name = "${var.container_name}-config"

  driver = "local"
  driver_opts = {
    type   = "none"
    device = var.config_path
    o      = "bind"
  }
}

resource "docker_container" "redis" {
  name    = var.container_name
  image   = docker_image.redis.image_id
  restart = var.restart_policy

  memory     = var.memory_limit_mib
  cpu_shares = var.cpu_shares

  user = var.run_as_user != "" ? var.run_as_user : null

  # Load ACL file and enable AOF persistence
  command = [
    "redis-server",
    "--aclfile", "/etc/redis/users.acl",
    "--appendonly", "yes",
    "--appendfilename", "appendonly.aof",
  ]

  ports {
    internal = 6379
    external = var.port
    # NET-002: bind to localhost only by default — internal service, not for public access
    ip = var.bind_address
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/data"
  }

  volumes {
    volume_name    = docker_volume.config.name
    container_path = "/etc/redis"
    read_only      = true
  }

  networks_advanced {
    name = var.network_name
  }

  healthcheck {
    test         = ["CMD", "redis-cli", "-a", var.admin_password, "ping"]
    interval     = "10s"
    timeout      = "5s"
    retries      = 5
    start_period = "5s"
  }

  labels {
    label = "platform.managed"
    value = "true"
  }

  labels {
    label = "platform.service"
    value = "redis"
  }

  labels {
    label = "platform.component"
    value = "data"
  }

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  # Regenerate container if ACL content changes (forces restart on ACL update).
  # On macOS Docker Desktop the kreuzwerker/docker provider auto-sets memory_swap
  # to the memory limit and reads an empty capabilities block back, producing a
  # perpetual diff that churns the container every apply — ignore both.
  lifecycle {
    replace_triggered_by = [local_file.acl]
    ignore_changes       = [memory_swap, capabilities]
  }

  depends_on = [local_file.acl]
}
