# modules/networking/docker-network

## What this module does

Creates a Docker network that provides a named, isolated layer-2 segment for platform services. Services joined to the same network can reach each other by container name; services on different networks cannot communicate unless explicitly connected.

## Why it exists

The platform runs Vault, Consul, and MinIO as Docker containers on self-hosted infrastructure (P8 — Terraform is the execution model). These services need network isolation from each other and from any non-platform containers on the host. A shared bridge network with a known name and CIDR makes service addressing deterministic and auditable.

Without this module, every root configuration would re-declare Docker networks inline, leading to inconsistency and violating IAC-003 (no hardcoded values).

## Why it was decided this way

**Platform Principle P8** mandates Terraform/OpenTofu as the execution model. Docker Compose was considered and rejected: it does not produce a plan output, cannot be reviewed before apply, and cannot satisfy IAC-002 (plan-before-apply). Terraform with the `kreuzwerker/docker` provider provides the same Docker management surface with full plan-apply governance.

**NET-001** (network segmentation) requires that platform services are placed in isolated network segments. A Docker bridge network with `internal = true` satisfies NET-001 for back-end services that must not route to the internet.

## How it serves the platform

| Consumer | Usage |
|---|---|
| `modules/hashicorp/vault` | Joins the Vault container to a dedicated back-end network |
| `modules/hashicorp/consul` | Joins Consul agents to the same network as Vault for health checks |
| `modules/storage/minio` | Joins MinIO to the platform storage network |
| `platform-infrastructure` | Creates the root networks consumed by all of the above |

## Usage

```hcl
module "platform_network" {
  source = "git::https://github.com/ashuangiras/platform-modules.git//modules/networking/docker-network?ref=v1.0.0"

  name   = "platform-backend"
  driver = "bridge"
  internal = true

  ipam_config = {
    subnet  = "10.100.0.0/24"
    gateway = "10.100.0.1"
  }

  labels = {
    "platform.env" = "production"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | required | Network name, unique on the host |
| `driver` | `string` | `"bridge"` | Docker network driver |
| `internal` | `bool` | `false` | Block external connectivity when true |
| `ipam_config` | `object` | `null` | Optional subnet/gateway assignment |
| `labels` | `map(string)` | `{}` | Labels for identification and filtering |

## Outputs

| Name | Description |
|---|---|
| `id` | Docker-assigned network ID |
| `name` | Network name |
| `driver` | Network driver |
| `subnet` | Assigned CIDR subnet |

## Provider requirements

| Provider | Version |
|---|---|
| `kreuzwerker/docker` | `~> 3.0` |
| Terraform | `~> 1.9` |
