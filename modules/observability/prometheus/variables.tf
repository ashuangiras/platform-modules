variable "container_name" {
  description = "Name of the Prometheus Docker container."
  type        = string
  default     = "prometheus"
}

variable "image_tag" {
  description = "Prometheus Docker image tag. Pin to a specific release. See https://hub.docker.com/r/prom/prometheus/tags"
  type        = string
  default     = "v3.0.1"
}

variable "config_path" {
  description = "Absolute path on the host containing prometheus.yml. Mounted read-only into the container."
  type        = string
}

variable "data_path" {
  description = "Absolute path on the host for Prometheus TSDB data persistence. Must exist and be writable by UID 65534 (nobody)."
  type        = string
}

variable "http_port" {
  description = "Host port to expose the Prometheus HTTP API and UI."
  type        = number
  default     = 9090
}

variable "network_name" {
  description = "Docker network to attach the Prometheus container to."
  type        = string
}

variable "retention_time" {
  description = "How long to retain metrics data. Examples: 15d, 30d, 6m."
  type        = string
  default     = "15d"
}

variable "restart_policy" {
  description = "Docker restart policy."
  type        = string
  default     = "unless-stopped"
}

variable "labels" {
  description = "Additional Docker labels."
  type        = map(string)
  default     = {}
}
