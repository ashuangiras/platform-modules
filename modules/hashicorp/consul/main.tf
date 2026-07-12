# Consul TLS configuration — written into the config-dir so the agent loads it.
# Only created when TLS is enabled. HTTP (8500) intentionally stays enabled
# alongside HTTPS (8501) during staging bring-up so the `consul members`
# healthcheck and initial bootstrap keep working (hardening to https-only is a
# documented follow-up).
resource "local_file" "tls_config" {
  count           = var.tls_enabled ? 1 : 0
  filename        = "${var.config_path}/tls.json"
  file_permission = "0644"
  content = jsonencode({
    ports = { https = 8501, http = 8500 }
    tls = {
      defaults = merge({
        cert_file       = "/consul/tls/tls.crt"
        key_file        = "/consul/tls/tls.key"
        verify_incoming = false
        verify_outgoing = var.tls_ca_path != ""
      }, var.tls_ca_path != "" ? { ca_file = "/consul/tls/ca.crt" } : {})
    }
  })
}

data "docker_registry_image" "consul" {
  name = "hashicorp/consul:${var.image_tag}"
}

resource "docker_image" "consul" {
  name          = data.docker_registry_image.consul.name
  pull_triggers = [data.docker_registry_image.consul.sha256_digest]
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

resource "docker_container" "consul" {
  name    = var.container_name
  image   = docker_image.consul.image_id
  restart = var.restart_policy

  memory     = var.memory_limit_mib
  cpu_shares = var.cpu_shares

  # The hashicorp/consul image uses su-exec to switch to the consul user.
  # Setting user here conflicts with su-exec on macOS Docker Desktop.
  # Leave empty to use the image default; set to "100:1000" on Linux hosts.
  user = var.run_as_user != "" ? var.run_as_user : null

  command = [
    "consul", "agent",
    "-server",
    "-bootstrap-expect=1",
    "-datacenter=${var.datacenter}",
    "-data-dir=/consul/data",
    "-config-dir=/consul/config",
    "-ui",
    "-client=0.0.0.0",
    "-bind=0.0.0.0",
    "-log-level=${var.log_level}",
  ]

  ports {
    internal = 8500
    external = var.http_port
    ip       = var.bind_address
    protocol = "tcp"
  }

  ports {
    internal = 8600
    external = var.dns_port
    ip       = var.bind_address
    protocol = "tcp"
  }

  ports {
    internal = 8600
    external = var.dns_port
    ip       = var.bind_address
    protocol = "udp"
  }

  # HTTPS API — only exposed when TLS is enabled.
  dynamic "ports" {
    for_each = var.tls_enabled ? [1] : []
    content {
      internal = 8501
      external = var.https_port
      ip       = var.bind_address
      protocol = "tcp"
    }
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/consul/data"
  }

  volumes {
    volume_name    = docker_volume.config.name
    container_path = "/consul/config"
    # read_only = false: consul image entrypoint chowns /consul/config on startup
  }

  # TLS server certificate — mounted read-only at a fixed container path.
  dynamic "volumes" {
    for_each = var.tls_enabled ? [1] : []
    content {
      host_path      = var.tls_cert_path
      container_path = "/consul/tls/tls.crt"
      read_only      = true
    }
  }

  # TLS server private key — mounted read-only at a fixed container path.
  dynamic "volumes" {
    for_each = var.tls_enabled ? [1] : []
    content {
      host_path      = var.tls_key_path
      container_path = "/consul/tls/tls.key"
      read_only      = true
    }
  }

  # TLS CA certificate — optional; only mounted when a CA path is supplied.
  dynamic "volumes" {
    for_each = var.tls_enabled && var.tls_ca_path != "" ? [1] : []
    content {
      host_path      = var.tls_ca_path
      container_path = "/consul/tls/ca.crt"
      read_only      = true
    }
  }

  networks_advanced {
    name = var.network_name
  }

  healthcheck {
    test         = ["CMD", "consul", "members"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 5
    start_period = "10s"
  }

  labels {
    label = "platform.managed"
    value = "true"
  }

  labels {
    label = "platform.service"
    value = "consul"
  }

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  # On macOS Docker Desktop the kreuzwerker/docker provider auto-sets memory_swap
  # to the memory limit and reads an empty capabilities block back, producing a
  # perpetual diff that churns the container on every apply — ignore both.
  lifecycle {
    ignore_changes = [memory_swap, capabilities]
  }
}
