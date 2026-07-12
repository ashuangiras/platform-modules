data "docker_registry_image" "minio" {
  name = "minio/minio:${var.image_tag}"
}

resource "docker_image" "minio" {
  name          = data.docker_registry_image.minio.name
  pull_triggers = [data.docker_registry_image.minio.sha256_digest]
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

resource "docker_container" "minio" {
  name    = var.container_name
  image   = docker_image.minio.image_id
  restart = var.restart_policy

  memory     = var.memory_limit_mib
  cpu_shares = var.cpu_shares

  # Run as non-root user (RUN-001)
  user = "1000:1000"

  command = concat(["server", "/data", "--console-address", ":${var.console_port}"], var.tls_enabled ? ["--certs-dir", "/certs"] : [])

  env = [
    "MINIO_ROOT_USER=${var.root_user}",
    "MINIO_ROOT_PASSWORD=${var.root_password}",
    # CI=true disables MinIO's large memory pre-allocation so the container starts
    # healthily under the RUN-008 memory cap (memory_limit_mib, default 512 MiB).
    "CI=true",
  ]

  ports {
    internal = 9000
    external = var.api_port
    ip       = var.bind_address
  }

  ports {
    internal = var.console_port
    external = var.console_port
    ip       = var.bind_address
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/data"
  }

  # TLS server certificate — MinIO's required filename in its certs dir.
  dynamic "volumes" {
    for_each = var.tls_enabled ? [1] : []
    content {
      host_path      = var.tls_cert_path
      container_path = "/certs/public.crt"
      read_only      = true
    }
  }

  # TLS server private key — MinIO's required filename in its certs dir.
  dynamic "volumes" {
    for_each = var.tls_enabled ? [1] : []
    content {
      host_path      = var.tls_key_path
      container_path = "/certs/private.key"
      read_only      = true
    }
  }

  # TLS CA certificate — optional; MinIO trusts CAs placed under /certs/CAs.
  dynamic "volumes" {
    for_each = var.tls_enabled && var.tls_ca_path != "" ? [1] : []
    content {
      host_path      = var.tls_ca_path
      container_path = "/certs/CAs/ca.crt"
      read_only      = true
    }
  }

  networks_advanced {
    name = var.network_name
  }

  healthcheck {
    # Under TLS the built-in `local` mc alias still points at http://, so `mc ready
    # local` reports "not ready" against the https listener. Re-point the alias to
    # https (self-signed → --insecure) using the root creds from the container env
    # before checking readiness.
    test = var.tls_enabled ? [
      "CMD-SHELL",
      "mc alias set local https://127.0.0.1:9000 \"$MINIO_ROOT_USER\" \"$MINIO_ROOT_PASSWORD\" --insecure >/dev/null 2>&1; mc --insecure ready local",
    ] : ["CMD", "mc", "ready", "local"]
    interval     = "30s"
    timeout      = "20s"
    retries      = 3
    start_period = "10s"
  }

  labels {
    label = "platform.managed"
    value = "true"
  }

  labels {
    label = "platform.service"
    value = "minio"
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
