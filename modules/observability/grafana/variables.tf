variable "container_name" {
  description = "Name of the Grafana Docker container."
  type        = string
  default     = "grafana"
}

variable "image_tag" {
  description = "Grafana Docker image tag. Pin to a specific release. See https://hub.docker.com/r/grafana/grafana/tags"
  type        = string
  default     = "11.3.0"
}

variable "data_path" {
  description = "Absolute path on the host for Grafana data (dashboards, datasources, users). Must exist and be writable by UID 472 (grafana)."
  type        = string
}

variable "http_port" {
  description = "Host port to expose the Grafana UI."
  type        = number
  default     = 3000
}

variable "network_name" {
  description = "Docker network to attach the Grafana container to."
  type        = string
}

variable "prometheus_url" {
  description = "URL of the Prometheus instance to configure as the default data source. Use the internal Docker network address."
  type        = string
}

variable "admin_password" {
  description = "Grafana admin password (sensitive). Set via TF_VAR or Vault."
  type        = string
  sensitive   = true
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

variable "oidc_config" {
  description = <<-EOT
    Optional Authentik OAuth2/OIDC configuration for Grafana.
    When set, GF_AUTH_GENERIC_OAUTH_* env vars are injected.
    Keys: client_id, client_secret, auth_url, token_url, api_url, name (default "Authentik").
  EOT
  type = object({
    client_id     = string
    client_secret = string
    auth_url      = string
    token_url     = string
    api_url       = string
    name          = optional(string, "Authentik")
  })
  sensitive = true
  default   = null
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
