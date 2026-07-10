resource "docker_network" "this" {
  name     = var.name
  driver   = var.driver
  internal = var.internal

  dynamic "ipam_config" {
    for_each = var.ipam_config != null ? [var.ipam_config] : []
    content {
      subnet  = ipam_config.value.subnet
      gateway = ipam_config.value.gateway
    }
  }

  labels {
    label = "platform.managed"
    value = "true"
  }

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}
