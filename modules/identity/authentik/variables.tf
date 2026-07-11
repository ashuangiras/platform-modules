variable "container_name_prefix" {
  description = "Prefix for Authentik container names (server + worker). Resulting names: <prefix>-server, <prefix>-worker."
  type        = string
  default     = "authentik"
}

variable "image_tag" {
  description = "Authentik Docker image tag. Pin to a specific release. See https://github.com/goauthentik/authentik/releases"
  type        = string
  default     = "2024.10.4"
}

variable "network_name" {
  description = "Docker network to attach Authentik containers to."
  type        = string
}

variable "http_port" {
  description = "Host port for Authentik HTTP (redirects to HTTPS or used directly behind a reverse proxy)."
  type        = number
  default     = 9000
}

variable "https_port" {
  description = "Host port for Authentik HTTPS."
  type        = number
  default     = 9443
}

variable "secret_key" {
  description = "Authentik SECRET_KEY — Django signing key. Must be 50+ random characters. Written to Vault by the caller."
  type        = string
  sensitive   = true
}

variable "database_url" {
  description = "PostgreSQL connection URL for Authentik. Format: postgresql://user:pass@host:port/dbname. Read from Vault via Vault Agent."
  type        = string
  sensitive   = true
}

variable "redis_url" {
  description = "Redis connection URL for Authentik. Format: redis://user:pass@host:port. Read from Vault via Vault Agent."
  type        = string
  sensitive   = true
}

variable "bootstrap_admin_email" {
  description = "Email for the Authentik bootstrap admin account (created on first run)."
  type        = string
  default     = "admin@platform.local"
}

variable "bootstrap_admin_password" {
  description = "Password for the Authentik bootstrap admin account. Written to Vault by the caller."
  type        = string
  sensitive   = true
}

variable "error_reporting_enabled" {
  description = "Enable Authentik's built-in error reporting (sends data to Sentry). Disable for air-gapped environments."
  type        = bool
  default     = false
}

variable "run_as_user" {
  description = "Container user. Set to empty string for image default (macOS Docker Desktop)."
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
