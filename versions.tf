terraform {
  # Minimum Terraform version required by all modules in this repository.
  # Use ~> to allow patch-level updates but pin the minor version.
  # SUP-001 (platform-compliance) requires a pinned required_version constraint.
  required_version = "~> 1.9"

  required_providers {
    # Docker provider — used by all modules in this repository.
    # All platform services (Vault, Consul, MinIO) are deployed as Docker containers
    # on self-hosted infrastructure per Platform Principle P8.
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
