data "docker_registry_image" "vault" {
  name = "hashicorp/vault:${var.image_tag}"
}

resource "docker_image" "vault" {
  name          = data.docker_registry_image.vault.name
  pull_triggers = [data.docker_registry_image.vault.sha256_digest]
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

resource "docker_container" "vault" {
  name    = var.container_name
  image   = docker_image.vault.image_id
  restart = var.restart_policy

  # Vault requires IPC_LOCK to prevent secrets being swapped to disk
  capabilities {
    add  = var.capabilities
    drop = ["ALL"]
  }

  # Run as the vault user (UID 100) — non-root per RUN-001
  user = "100:1000"

  command = ["vault", "server", "-config=/vault/config"]

  env = [
    "VAULT_LOG_LEVEL=${var.vault_log_level}",
    "VAULT_ADDR=http://0.0.0.0:${var.api_port}",
  ]

  ports {
    internal = var.api_port
    external = var.api_port
  }

  ports {
    internal = var.cluster_port
    external = var.cluster_port
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/vault/data"
  }

  volumes {
    volume_name    = docker_volume.config.name
    container_path = "/vault/config"
    read_only      = true
  }

  networks_advanced {
    name = var.network_name
  }

  healthcheck {
    test         = ["CMD", "vault", "status", "-address=http://127.0.0.1:${var.api_port}"]
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
    value = "vault"
  }

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}
