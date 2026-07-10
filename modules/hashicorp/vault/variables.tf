variable "container_name" {
  description = "Name of the Vault Docker container."
  type        = string
  default     = "vault"
}

variable "image_tag" {
  description = "HashiCorp Vault Docker image tag. Pin to a specific release. See https://hub.docker.com/r/hashicorp/vault/tags"
  type        = string
  default     = "1.18.3"
}

variable "data_path" {
  description = "Absolute path on the host where Vault data (file storage backend) is persisted. Must exist before apply. Back up this directory per BAK-001."
  type        = string
}

variable "config_path" {
  description = "Absolute path on the host containing the Vault config file (vault.hcl). The directory must exist and contain a valid vault.hcl before apply."
  type        = string
}

variable "api_port" {
  description = "Host port to expose the Vault API on. Default 8200 matches the Vault standard port."
  type        = number
  default     = 8200
}

variable "cluster_port" {
  description = "Host port for Vault cluster (HA) communication."
  type        = number
  default     = 8201
}

variable "network_name" {
  description = "Docker network to attach this container to. Use the docker-network module."
  type        = string
}

variable "vault_log_level" {
  description = "Vault log level. One of: trace, debug, info, warn, error."
  type        = string
  default     = "info"

  validation {
    condition     = contains(["trace", "debug", "info", "warn", "error"], var.vault_log_level)
    error_message = "vault_log_level must be one of: trace, debug, info, warn, error."
  }
}

variable "restart_policy" {
  description = "Docker restart policy."
  type        = string
  default     = "unless-stopped"
}

variable "capabilities" {
  description = "Linux capabilities to add to the container. IPC_LOCK is required by Vault to prevent secrets from being swapped to disk."
  type        = list(string)
  default     = ["IPC_LOCK"]
}

variable "labels" {
  description = "Additional Docker labels."
  type        = map(string)
  default     = {}
}
