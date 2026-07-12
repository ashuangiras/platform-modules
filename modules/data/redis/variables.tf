variable "container_name" {
  description = "Name of the Redis Docker container."
  type        = string
  default     = "redis"
}

variable "image_tag" {
  description = "Redis Docker image tag. Pin to a specific release. Use a 7.x tag for ACL support."
  type        = string
  default     = "7.4-alpine"
}

variable "data_path" {
  description = "Host path for Redis data (AOF/RDB persistence). Must exist before apply."
  type        = string
}

variable "config_path" {
  description = "Host path where the generated redis.conf and users.acl files will be written. Must exist before apply."
  type        = string
}

variable "port" {
  description = "Host port to expose Redis on."
  type        = number
  default     = 6379
}

variable "network_name" {
  description = "Docker network to attach the Redis container to."
  type        = string
}

variable "admin_password" {
  description = "Password for the built-in 'admin' ACL user (full access). Written to Vault by the caller."
  type        = string
  sensitive   = true
}

variable "acl_users" {
  description = <<-EOT
    Map of service_name → { password, commands, key_prefix } for per-service ACL users.
    - password: the service's Redis password (written to Vault by the caller)
    - commands: Redis ACL command string, e.g. "+@all" or "+@read +@write"
    - key_prefix: key namespace, e.g. "authentik:*" (use "" for no restriction)
    The default 'default' user is always disabled.
  EOT
  type = map(object({
    password   = string
    commands   = string
    key_prefix = string
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
  description = "Container user. Set to empty string for image default (macOS Docker Desktop)."
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
  default     = 128
}

variable "cpu_shares" {
  description = "CPU shares for the container (relative weight, 1024 = 1 vCPU equivalent)."
  type        = number
  default     = 256
}

variable "bind_address" {
  description = "Host IP address to bind exposed container ports to. Defaults to 127.0.0.1 (localhost-only, the secure default per NET-002). Set to \"0.0.0.0\" only if the service must be reachable on all host interfaces."
  type        = string
  default     = "127.0.0.1"
}
