variable "container_name" {
  description = "Name of the PostgreSQL Docker container."
  type        = string
  default     = "postgresql"
}

variable "image_tag" {
  description = "PostgreSQL Docker image tag. Pin to a specific release."
  type        = string
  default     = "16.4-alpine"
}

variable "data_path" {
  description = "Host path for PostgreSQL data persistence. Must exist before apply."
  type        = string
}

variable "port" {
  description = "Host port to expose PostgreSQL on."
  type        = number
  default     = 5432
}

variable "network_name" {
  description = "Docker network to attach the PostgreSQL container to."
  type        = string
}

variable "superuser_password" {
  description = "PostgreSQL superuser (postgres) password. Written to Vault by the caller."
  type        = string
  sensitive   = true
}

variable "databases" {
  description = <<-EOT
    Map of service_name → { password } to create as database + owner role pairs.
    Each entry creates:
      - A database named after the key
      - A role (username) named after the key with a limited-privilege owner grant
    Credentials are written to Vault by the caller using these outputs.
  EOT
  type = map(object({
    password = string
  }))
  sensitive = true
  default   = {}
}

variable "restart_policy" {
  description = "Docker restart policy."
  type        = string
  default     = "unless-stopped"
}

variable "run_as_user" {
  description = "User to run the container as. Set to empty string for image default (macOS Docker Desktop)."
  type        = string
  default     = ""
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
  default     = 512
}

variable "bind_address" {
  description = "Host IP address to bind exposed container ports to. Defaults to 127.0.0.1 (localhost-only, the secure default per NET-002). Set to \"0.0.0.0\" only if the service must be reachable on all host interfaces."
  type        = string
  default     = "127.0.0.1"
}
