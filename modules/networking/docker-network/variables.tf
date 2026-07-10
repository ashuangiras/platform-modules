variable "name" {
  description = "Name of the Docker network. Must be unique on the host."
  type        = string
}

variable "driver" {
  description = "Docker network driver. 'bridge' for single-host; 'overlay' for multi-host Swarm."
  type        = string
  default     = "bridge"

  validation {
    condition     = contains(["bridge", "overlay", "host", "none", "macvlan"], var.driver)
    error_message = "driver must be one of: bridge, overlay, host, none, macvlan."
  }
}

variable "internal" {
  description = "When true, no external connectivity is allowed. Use for back-end service networks that must not reach the internet."
  type        = bool
  default     = false
}

variable "ipam_config" {
  description = "Optional IPAM configuration block. Leave null to use Docker's automatic address assignment."
  type = object({
    subnet  = string
    gateway = optional(string)
  })
  default = null
}

variable "labels" {
  description = "Key-value labels to attach to the network for identification and filtering."
  type        = map(string)
  default     = {}
}
