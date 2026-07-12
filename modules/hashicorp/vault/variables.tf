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

variable "drop_capabilities" {
  description = "Linux capabilities to drop. Set to [] on macOS Docker Desktop or environments that restrict capability management."
  type        = list(string)
  default     = ["ALL"]
}

variable "run_as_user" {
  description = "User to run the container as (UID:GID). Set to empty string to use the image default (required on macOS Docker Desktop)."
  type        = string
  default     = "100:1000"
}

variable "labels" {
  description = "Additional Docker labels."
  type        = map(string)
  default     = {}
}

variable "keys_path" {
  description = <<-EOT
    Absolute path on the host where Vault init output (unseal keys + root token) is stored.
    Created on first init and read on every subsequent apply to unseal a restarted container.
    This file contains plaintext secrets — it must never be committed to version control.
    Recommended: a path outside the repo, e.g. ~/.platform/vault-keys.json.
  EOT
  type        = string
  default     = "~/.platform/vault-keys.json"
}

variable "logs_path" {
  description = "Absolute host path for Vault audit logs. Mounted at /vault/logs inside the container. Create this directory before apply."
  type        = string
  default     = ""
}

variable "memory_limit_mib" {
  description = "Container memory limit in MiB (RUN-008). 0 = no limit (not recommended). Vault needs ≥512: with mlock, the file backend, an audit device, and the CLI-based healthcheck spawning a second vault process, 256 MiB OOM-kills the server."
  type        = number
  default     = 512
}

variable "cpu_shares" {
  description = "CPU shares for the container (relative weight, 1024 = 1 vCPU equivalent)."
  type        = number
  default     = 512
}

variable "bind_address" {
  description = "Host IP address to bind exposed container ports to. Defaults to 127.0.0.1 (localhost-only, the secure default per NET-002). Set to \"0.0.0.0\" only if the service must be reachable on all host interfaces."
  type        = string
  default     = "127.0.0.1"
}

variable "tls_enabled" {
  description = "Enable TLS on the Vault listener. When false (default) the service runs plaintext, preserving current behavior. When true, cert material is bind-mounted read-only and the CLI/env scheme/healthcheck are switched to HTTPS. The listener itself is set in the operator-owned vault.hcl."
  type        = bool
  default     = false
}

variable "tls_cert_path" {
  description = "Absolute host path to the Vault server certificate (PEM). Bind-mounted read-only into the container at /vault/tls/tls.crt when tls_enabled = true."
  type        = string
  default     = ""
}

variable "tls_key_path" {
  description = "Absolute host path to the Vault server private key (PEM). Bind-mounted read-only into the container at /vault/tls/tls.key when tls_enabled = true."
  type        = string
  default     = ""
}

variable "tls_ca_path" {
  description = "Absolute host path to the CA certificate (PEM) that signed the Vault server cert. Optional; bind-mounted read-only at /vault/tls/ca.crt when set and tls_enabled = true."
  type        = string
  default     = ""
}
