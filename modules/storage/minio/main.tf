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

  # Run as non-root user (RUN-001)
  user = "1000:1000"

  command = ["server", "/data", "--console-address", ":${var.console_port}"]

  env = [
    "MINIO_ROOT_USER=${var.root_user}",
    "MINIO_ROOT_PASSWORD=${var.root_password}",
  ]

  ports {
    internal = 9000
    external = var.api_port
  }

  ports {
    internal = var.console_port
    external = var.console_port
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/data"
  }

  networks_advanced {
    name = var.network_name
  }

  healthcheck {
    test         = ["CMD", "mc", "ready", "local"]
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
}
