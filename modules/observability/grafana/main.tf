data "docker_registry_image" "grafana" {
  name = "grafana/grafana:${var.image_tag}"
}

resource "docker_image" "grafana" {
  name          = data.docker_registry_image.grafana.name
  pull_triggers = [data.docker_registry_image.grafana.sha256_digest]
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

resource "docker_container" "grafana" {
  name    = var.container_name
  image   = docker_image.grafana.image_id
  restart = var.restart_policy

  memory     = var.memory_limit_mib
  cpu_shares = var.cpu_shares

  # grafana/grafana runs as grafana user (UID 472) — non-root per RUN-001
  user = "472:472"

  env = concat(
    [
      "GF_PATHS_DATA=/var/lib/grafana",
      "GF_SERVER_HTTP_PORT=3000",
      # Pre-configure Prometheus as the default data source
      "GF_DATASOURCES_DEFAULT_NAME=Prometheus",
      "GF_DATASOURCES_DEFAULT_TYPE=prometheus",
      "GF_DATASOURCES_DEFAULT_URL=${var.prometheus_url}",
      "GF_DATASOURCES_DEFAULT_ACCESS=proxy",
      "GF_DATASOURCES_DEFAULT_IS_DEFAULT=true",
    ],
    var.admin_password != "" ? ["GF_SECURITY_ADMIN_PASSWORD=${var.admin_password}"] : [],
    # Authentik OIDC — injected when oidc_config is provided (RUN-009 / RUN-009b)
    var.oidc_config != null ? [
      "GF_AUTH_GENERIC_OAUTH_ENABLED=true",
      "GF_AUTH_GENERIC_OAUTH_NAME=${var.oidc_config.name}",
      "GF_AUTH_GENERIC_OAUTH_CLIENT_ID=${var.oidc_config.client_id}",
      "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=${var.oidc_config.client_secret}",
      "GF_AUTH_GENERIC_OAUTH_SCOPES=openid email profile",
      "GF_AUTH_GENERIC_OAUTH_AUTH_URL=${var.oidc_config.auth_url}",
      "GF_AUTH_GENERIC_OAUTH_TOKEN_URL=${var.oidc_config.token_url}",
      "GF_AUTH_GENERIC_OAUTH_API_URL=${var.oidc_config.api_url}",
      "GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups[*], 'platform-admins') && 'Admin' || 'Viewer'",
      "GF_AUTH_GENERIC_OAUTH_USE_PKCE=true",
    ] : []
  )

  ports {
    internal = 3000
    external = var.http_port
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/var/lib/grafana"
  }

  networks_advanced {
    name = var.network_name
  }

  # OBS-001: health check endpoint at /api/health
  healthcheck {
    test         = ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/api/health"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  labels {
    label = "platform.managed"
    value = "true"
  }

  labels {
    label = "platform.service"
    value = "grafana"
  }

  labels {
    label = "platform.component"
    value = "observability"
  }

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}
