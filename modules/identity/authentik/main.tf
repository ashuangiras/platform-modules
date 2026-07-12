locals {
  # Common environment variables shared by server and worker
  common_env = concat(
    [
      "AUTHENTIK_SECRET_KEY=${var.secret_key}",
      # PostgreSQL — Authentik requires individual vars, not a connection URL
      "AUTHENTIK_POSTGRESQL__HOST=${var.pg_host}",
      "AUTHENTIK_POSTGRESQL__PORT=${var.pg_port}",
      "AUTHENTIK_POSTGRESQL__USER=${var.pg_user}",
      "AUTHENTIK_POSTGRESQL__PASSWORD=${var.pg_password}",
      "AUTHENTIK_POSTGRESQL__NAME=${var.pg_name}",
      # Redis — individual vars (AUTHENTIK_REDIS__URL is not a valid config key)
      "AUTHENTIK_REDIS__HOST=${var.redis_host}",
      "AUTHENTIK_REDIS__PORT=${var.redis_port}",
      "AUTHENTIK_REDIS__USERNAME=${var.redis_user}",
      "AUTHENTIK_REDIS__PASSWORD=${var.redis_password}",
      "AUTHENTIK_ERROR_REPORTING__ENABLED=${var.error_reporting_enabled}",
      # Bootstrap admin — only applied on first run; ignored if admin already exists
      "AUTHENTIK_BOOTSTRAP_EMAIL=${var.bootstrap_admin_email}",
      "AUTHENTIK_BOOTSTRAP_PASSWORD=${var.bootstrap_admin_password}",
    ],
    # Bootstrap API token — set once on first run; used by Terraform integrations provider
    var.bootstrap_token != "" ? ["AUTHENTIK_BOOTSTRAP_TOKEN=${var.bootstrap_token}"] : []
  )

  platform_labels = merge(
    {
      "platform.managed"   = "true"
      "platform.component" = "identity"
      "platform.service"   = "authentik"
    },
    var.labels
  )
}

data "docker_registry_image" "authentik" {
  name = "ghcr.io/goauthentik/server:${var.image_tag}"
}

resource "docker_image" "authentik" {
  name          = data.docker_registry_image.authentik.name
  pull_triggers = [data.docker_registry_image.authentik.sha256_digest]
  keep_locally  = true
}

# ── Authentik Server ──────────────────────────────────────────────────────────
resource "docker_container" "server" {
  memory     = var.memory_limit_mib
  cpu_shares = var.cpu_shares
  name       = "${var.container_name_prefix}-server"
  image      = docker_image.authentik.image_id
  restart    = var.restart_policy

  user    = var.run_as_user != "" ? var.run_as_user : null
  command = ["server"]

  env = local.common_env

  ports {
    internal = 9000
    external = var.http_port
    ip       = var.bind_address
  }

  ports {
    internal = 9443
    external = var.https_port
    ip       = var.bind_address
  }

  # Custom TLS cert material — mounted read-only into Authentik's discovery dir.
  # Only mounted when tls_enabled = true; otherwise Authentik uses its bundled
  # self-signed cert on 9443 (current behavior).
  dynamic "volumes" {
    for_each = var.tls_enabled ? [1] : []
    content {
      host_path      = var.tls_cert_path
      container_path = "/certs/tls.crt"
      read_only      = true
    }
  }

  dynamic "volumes" {
    for_each = var.tls_enabled ? [1] : []
    content {
      host_path      = var.tls_key_path
      container_path = "/certs/tls.key"
      read_only      = true
    }
  }

  dynamic "volumes" {
    for_each = var.tls_enabled && var.tls_ca_path != "" ? [1] : []
    content {
      host_path      = var.tls_ca_path
      container_path = "/certs/ca.crt"
      read_only      = true
    }
  }

  networks_advanced {
    name = var.network_name
  }

  healthcheck {
    test         = ["CMD", "ak", "healthcheck"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 5
    start_period = "1m0s"
  }

  dynamic "labels" {
    for_each = local.platform_labels
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

# ── Authentik Worker ──────────────────────────────────────────────────────────
# The worker handles background tasks: email, policies, flows, LDAP sync.
resource "docker_container" "worker" {
  name       = "${var.container_name_prefix}-worker"
  image      = docker_image.authentik.image_id
  restart    = var.restart_policy
  memory     = var.memory_limit_mib
  cpu_shares = var.cpu_shares

  user    = var.run_as_user != "" ? var.run_as_user : null
  command = ["worker"]

  env = local.common_env

  networks_advanced {
    name = var.network_name
  }

  healthcheck {
    test         = ["CMD", "ak", "healthcheck"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 5
    start_period = "1m0s"
  }

  dynamic "labels" {
    for_each = local.platform_labels
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
