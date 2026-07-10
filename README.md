# platform-modules

Reusable Terraform modules for the self-hosted platform. Governed by [platform-compliance](https://github.com/ashuangiras/platform-compliance) at profile `PROF-TERRAFORM-MODULE-V1`.

All modules use the [`kreuzwerker/docker`](https://registry.terraform.io/providers/kreuzwerker/docker/latest) provider. Platform services run as Docker containers on self-hosted infrastructure per [Platform Principle P8](https://github.com/ashuangiras/platform-compliance/blob/main/platform-principles.md).

## Module catalogue

### Networking

| Module | Purpose | Rationale |
|---|---|---|
| [`modules/networking/docker-network`](modules/networking/docker-network/README.md) | Named Docker network for service isolation | NET-001 |

### Storage

| Module | Purpose | Rationale |
|---|---|---|
| [`modules/storage/minio`](modules/storage/minio/README.md) | MinIO S3-compatible object storage — Terraform state backend and platform storage | ADR-0014 |

### HashiCorp

| Module | Purpose | Rationale |
|---|---|---|
| [`modules/hashicorp/vault`](modules/hashicorp/vault/README.md) | HashiCorp Vault — secret management backend | ADR-0008 |
| [`modules/hashicorp/consul`](modules/hashicorp/consul/README.md) | HashiCorp Consul — service discovery and application configuration | ADR-0019 |

## Deployment order

`platform-infrastructure` deploys these modules in dependency order:

```
docker-network  ←── all containers attach to this
     │
     ├── minio   ←── deploy first; needed for Terraform state migration (ADR-0014)
     ├── vault   ←── required before any service deploys (ADR-0008)
     └── consul  ←── required before services register and fetch config (ADR-0019)
```

## Compliance

This repository is governed by [PROF-TERRAFORM-MODULE-V1](https://github.com/ashuangiras/platform-compliance/blob/main/04-profiles/PROF-TERRAFORM-MODULE-V1.yaml). Every PR must pass the 7-job compliance gate (tfsec, OPA policies, assessment).

See [.github/copilot-instructions.md](.github/copilot-instructions.md) for the agent team and pre/post-flight checklist.
