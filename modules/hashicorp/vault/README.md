# modules/hashicorp/vault

## What this module does

Deploys a [HashiCorp Vault](https://developer.hashicorp.com/vault) instance as a Docker container on the local platform host. Vault is the platform's secret management backend — it stores and controls access to tokens, passwords, certificates, and API keys for all platform services.

The container:
- Mounts a host directory for persistent Vault storage data (file backend, upgradeable to Raft HA later)
- Mounts a host directory containing `vault.hcl` as read-only config
- Runs as UID 100 (the Vault non-root user) with `IPC_LOCK` capability to prevent secrets being written to swap
- Exposes the Vault API on a configurable host port (default 8200)

## Why it exists

**ADR-0008** (Secret Management Backend) ratified HashiCorp Vault as the platform's secret injection backend. No service in `platform-services` may store or inject plaintext secrets outside of Vault. Before any service can be deployed, Vault must be operational and the service's secrets must be loaded.

This module provides the reusable, governed deployment of Vault so that `platform-infrastructure` can declare it as a first-class Terraform resource rather than a manually-operated process.

## Why it was decided this way

**Vault over alternatives** — SOPS+age, GitHub Secrets, and environment variables were evaluated in ADR-0008. Vault was chosen because it supports dynamic secrets, fine-grained RBAC (AppRole per service), audit logging (AUD-001), and the GitHub OIDC auth method needed for CI pipelines (SEC-001 — no static credentials in workflows).

**Docker over a native install** — Running Vault as a managed Docker container provides a consistent deployment surface across hosts, enables plan-before-apply (IAC-002), and allows the container image tag to be pinned and drift-checked (SUP-001).

**`IPC_LOCK` capability** — Vault requires the ability to call `mlock()` to prevent sensitive pages from being swapped to disk. All other capabilities are dropped (`drop = ["ALL"]`), satisfying RUN-001 (least-privilege container posture).

**File storage backend** — Vault's built-in file backend is used initially. It is simple, requires no external dependency, and is backed up by the operator's BAK-001 obligation on `data_path`. The file backend is upgradeable to Vault's Raft integrated storage (HA) without re-deploying services.

## How it serves the platform

| Consumer | Usage |
|---|---|
| `platform-infrastructure` | Deploys Vault; initialises it and stores the unseal keys securely |
| All services in `platform-services` | Authenticate via AppRole or GitHub OIDC and fetch secrets at startup |
| GitHub Actions CI | Authenticate via GitHub OIDC → Vault JWT auth and receive short-lived tokens |
| Consul (ADR-0019) | Vault issues TLS certificates for Consul Connect mTLS |

## Pre-deployment prerequisites

Before running `terraform apply` for this module:

1. Create `data_path` on the host: `mkdir -p /srv/platform/vault/data && chown 100:1000 /srv/platform/vault/data`
2. Create `config_path` on the host: `mkdir -p /srv/platform/vault/config`
3. Write `vault.hcl` into `config_path`:

```hcl
# /srv/platform/vault/config/vault.hcl
storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true   # TLS terminated at the load balancer or host-level proxy
}

ui = true
api_addr     = "http://0.0.0.0:8200"
cluster_addr = "http://0.0.0.0:8201"
```

4. After first apply, initialise Vault: `vault operator init`  
   Store the unseal keys and root token in a secure offline location. Do not commit them.

## Usage

```hcl
module "vault" {
  source = "git::https://github.com/ashuangiras/platform-modules.git//modules/hashicorp/vault?ref=v1.0.0"

  container_name = "platform-vault"
  data_path      = "/srv/platform/vault/data"
  config_path    = "/srv/platform/vault/config"
  network_name   = module.platform_network.name
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `container_name` | `string` | `"vault"` | Container name |
| `image_tag` | `string` | `1.18.3` | Vault image tag — pin to a specific release |
| `data_path` | `string` | required | Host path for Vault storage data |
| `config_path` | `string` | required | Host path containing `vault.hcl` |
| `api_port` | `number` | `8200` | Host port for Vault API |
| `cluster_port` | `number` | `8201` | Host port for Vault cluster |
| `network_name` | `string` | required | Docker network to attach to |
| `vault_log_level` | `string` | `"info"` | Log verbosity |
| `restart_policy` | `string` | `"unless-stopped"` | Docker restart policy |
| `capabilities` | `list(string)` | `["IPC_LOCK"]` | Linux capabilities to add |
| `labels` | `map(string)` | `{}` | Additional container labels |

## Outputs

| Name | Description |
|---|---|
| `container_id` | Docker container ID |
| `container_name` | Container hostname on the network |
| `api_address` | Vault API URL from the host (`http://localhost:8200`) |
| `api_address_internal` | Vault API URL from containers on the same network |
