variable "container_name" {
  description = "Name of the Consul Docker container."
  type        = string
  default     = "consul"
}

variable "image_tag" {
  description = "HashiCorp Consul Docker image tag. Pin to a specific release. See https://hub.docker.com/r/hashicorp/consul/tags"
  type        = string
  default     = "1.20.2"
}

variable "data_path" {
  description = "Absolute path on the host for Consul data persistence (Raft log, KV snapshots). Must exist before apply. Back up per BAK-001."
  type        = string
}

variable "config_path" {
  description = "Absolute path on the host containing Consul config files (*.hcl or *.json). Mounted read-only into the container."
  type        = string
}

variable "http_port" {
  description = "Host port for the Consul HTTP API and UI."
  type        = number
  default     = 8500
}

variable "dns_port" {
  description = "Host port for Consul DNS interface."
  type        = number
  default     = 8600
}

variable "network_name" {
  description = "Docker network to attach this container to. Use the docker-network module."
  type        = string
}

variable "datacenter" {
  description = "Consul datacenter name. Must match across all agents in the same cluster."
  type        = string
  default     = "platform-dc1"
}

variable "log_level" {
  description = "Consul log level."
  type        = string
  default     = "info"

  validation {
    condition     = contains(["trace", "debug", "info", "warn", "error"], var.log_level)
    error_message = "log_level must be one of: trace, debug, info, warn, error."
  }
}

variable "run_as_user" {
  description = "User to run the container as (UID:GID). The hashicorp/consul image uses su-exec internally — set to empty string to let the image handle user switching (required on macOS Docker Desktop)."
  type        = string
  default     = ""
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

variable "memory_limit_mib" {
  description = "Container memory limit in MiB (RUN-008). 0 = no limit (not recommended)."
  type        = number
  default     = 256
}

variable "cpu_shares" {
  description = "CPU shares for the container (relative weight, 1024 = 1 vCPU equivalent)."
  type        = number
  default     = 256
}
