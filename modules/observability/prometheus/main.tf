data "docker_registry_image" "prometheus" {
  name = "prom/prometheus:${var.image_tag}"
}

resource "docker_image" "prometheus" {
  name          = data.docker_registry_image.prometheus.name
  pull_triggers = [data.docker_registry_image.prometheus.sha256_digest]
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

resource "docker_container" "prometheus" {
  name    = var.container_name
  image   = docker_image.prometheus.image_id
  restart = var.restart_policy

  # prom/prometheus runs as nobody (UID 65534) by default — non-root per RUN-001
  user = "65534:65534"

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=${var.retention_time}",
    "--web.console.libraries=/etc/prometheus/console_libraries",
    "--web.console.templates=/etc/prometheus/consoles",
    "--web.enable-lifecycle", # allows config reload via HTTP POST /-/reload
  ]

  ports {
    internal = 9090
    external = var.http_port
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/prometheus"
  }

  volumes {
    volume_name    = docker_volume.config.name
    container_path = "/etc/prometheus"
    read_only      = true
  }

  networks_advanced {
    name = var.network_name
  }

  # OBS-001: health check endpoint at /-/healthy
  healthcheck {
    test         = ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9090/-/healthy"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "15s"
  }

  labels {
    label = "platform.managed"
    value = "true"
  }

  labels {
    label = "platform.service"
    value = "prometheus"
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
