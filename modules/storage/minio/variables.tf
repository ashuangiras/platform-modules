variable "container_name" {
  description = "Name of the MinIO Docker container."
  type        = string
  default     = "minio"
}

variable "image_tag" {
  description = "MinIO Docker image tag. Pin to a specific release for reproducibility. See https://hub.docker.com/r/minio/minio/tags"
  type        = string
  default     = "RELEASE.2024-11-07T00-52-20Z"
}

variable "data_path" {
  description = "Absolute path on the host where MinIO data is persisted. Must exist before apply. Back up this directory per BAK-001."
  type        = string
}

variable "api_port" {
  description = "Host port to expose the MinIO S3 API on. Default 9000 matches the MinIO standard port."
  type        = number
  default     = 9000
}

variable "console_port" {
  description = "Host port to expose the MinIO console UI on."
  type        = number
  default     = 9001
}

variable "root_user" {
  description = "MinIO root (admin) username. Store in Vault; do not hardcode."
  type        = string
  sensitive   = true
}

variable "root_password" {
  description = "MinIO root (admin) password. Must be at least 8 characters. Store in Vault; do not hardcode."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.root_password) >= 8
    error_message = "root_password must be at least 8 characters."
  }
}

variable "network_name" {
  description = "Name of the Docker network to attach this container to. Use the docker-network module to create this."
  type        = string
}

variable "restart_policy" {
  description = "Docker restart policy for the MinIO container."
  type        = string
  default     = "unless-stopped"

  validation {
    condition     = contains(["no", "always", "on-failure", "unless-stopped"], var.restart_policy)
    error_message = "restart_policy must be one of: no, always, on-failure, unless-stopped."
  }
}

variable "labels" {
  description = "Additional Docker labels to apply to the container."
  type        = map(string)
  default     = {}
}

variable "memory_limit_mib" {
  description = "Container memory limit in MiB (RUN-008). 0 = no limit (not recommended)."
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
  description = "Enable TLS on the MinIO listener. When false (default) the service runs plaintext, preserving current behavior. When true, cert material is bind-mounted read-only into MinIO's certs dir and MinIO serves HTTPS on the API and console automatically."
  type        = bool
  default     = false
}

variable "tls_cert_path" {
  description = "Absolute host path to the MinIO server certificate (PEM). Bind-mounted read-only into the container at /certs/public.crt when tls_enabled = true."
  type        = string
  default     = ""
}

variable "tls_key_path" {
  description = "Absolute host path to the MinIO server private key (PEM). Bind-mounted read-only into the container at /certs/private.key when tls_enabled = true."
  type        = string
  default     = ""
}

variable "tls_ca_path" {
  description = "Absolute host path to the CA certificate (PEM) that signed the MinIO server cert. Optional; bind-mounted read-only at /certs/CAs/ca.crt when set and tls_enabled = true."
  type        = string
  default     = ""
}
