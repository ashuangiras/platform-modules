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
    protocol = "tcp"
  }

  ports {
    internal = 8600
    external = var.dns_port
    protocol = "tcp"
  }

  ports {
    internal = 8600
    external = var.dns_port
    protocol = "udp"
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
}
