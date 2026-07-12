# modules/hashicorp/consul

## What this module does

Deploys a single-node [HashiCorp Consul](https://developer.hashicorp.com/consul) agent in server mode as a Docker container. Consul provides three capabilities used by the platform:

1. **Service discovery** — services register themselves and are reachable via `<name>.service.consul` DNS
2. **Key-Value store** — governed application configuration (feature flags, endpoint URLs, tuning parameters)
3. **Consul Connect** (optional, adopted per service) — mTLS between services without manual certificate management

## Why it exists

**ADR-0019** (Application Configuration Management) ratified Consul as the platform's configuration and service discovery layer. Services must not use environment variables for non-trivial configuration — configuration stored in Consul is versioned, auditable, and governed by CHG-001 for platform-critical paths.

Service discovery via Consul DNS eliminates hardcoded IP addresses and hostnames from service configuration, satisfying IAC-003 at the service layer.

## Why it was decided this way

**Consul over alternatives** — etcd was considered; Consul was chosen because it is designed as a unified service mesh and configuration store, integrates natively with Vault (certificate backend for Consul Connect), and has a stable Terraform provider. etcd is primarily a distributed key-value store focused on Kubernetes coordination — it lacks the service mesh and service discovery features Consul provides.

**Single-node bootstrap** (`-bootstrap-expect=1`) — The initial deployment uses a single Consul server node. This is sufficient for the platform bootstrap phase. HA Raft clustering (3+ nodes) is a future growth item tracked in Phase D. The single-node flag is declared explicitly so the intent is visible and the upgrade path is clear.

**File-backed Raft storage** — Consul uses its own integrated Raft storage (the `-data-dir` flag). Like Vault's file backend, this requires no external coordination dependency and is straightforward to back up.

**Docker over native install** — Same rationale as `modules/hashicorp/vault`: Terraform-managed container for plan-reviewable, pinned-version deployment.

## How it serves the platform

| Consumer | Usage |
|---|---|
| `platform-infrastructure` | Deploys Consul; registers infrastructure services |
| All services in `platform-services` | Register with Consul at startup; receive DNS-based peer discovery |
| Vault (ADR-0008) | Consul Connect mTLS certificates — Vault issues the CA; Consul uses it |
| GitHub Actions CI | Consul KV provides environment-specific configuration values to CI pipelines |

## Configuration governance (CHG-001 binding)

Changes to Consul KV paths under `config/platform/` must:
1. Reference a Change Record (`CHG-YYYYMMDD-NNN`) in the commit or PR body
2. Be applied via `terraform apply` (not `consul kv put` ad-hoc) for auditability

SEC-001 applies: no secrets may be stored in Consul KV. Secrets go to Vault.

## Pre-deployment prerequisites

1. Create host directories:
   ```bash
   mkdir -p /srv/platform/consul/data /srv/platform/consul/config
   chown 100:1000 /srv/platform/consul/data /srv/platform/consul/config
   ```

2. Write a minimal config file (ACLs recommended for production):
   ```hcl
   # /srv/platform/consul/config/consul.hcl
   datacenter = "platform-dc1"
   data_dir   = "/consul/data"
   ui_config { enabled = true }
   ```

## Usage

```hcl
module "consul" {
  source = "git::https://github.com/ashuangiras/platform-modules.git//modules/hashicorp/consul?ref=v1.0.0"

  container_name = "platform-consul"
  data_path      = "/srv/platform/consul/data"
  config_path    = "/srv/platform/consul/config"
  network_name   = module.platform_network.name
  datacenter     = "platform-dc1"
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `container_name` | `string` | `"consul"` | Container name |
| `image_tag` | `string` | `1.20.2` | Consul image tag — pin to a specific release |
| `data_path` | `string` | required | Host path for Consul data |
| `config_path` | `string` | required | Host path for Consul config files |
| `http_port` | `number` | `8500` | Host port for HTTP API and UI |
| `dns_port` | `number` | `8600` | Host port for DNS |
| `network_name` | `string` | required | Docker network to attach to |
| `datacenter` | `string` | `"platform-dc1"` | Consul datacenter name |
| `log_level` | `string` | `"info"` | Log verbosity |
| `restart_policy` | `string` | `"unless-stopped"` | Docker restart policy |
| `labels` | `map(string)` | `{}` | Additional container labels |
| `bind_address` | `string` | `"127.0.0.1"` | Host IP the exposed ports bind to (localhost-only default, NET-002) |
| `https_port` | `number` | `8501` | Host port for the HTTPS API (only exposed when `tls_enabled = true`) |
| `tls_enabled` | `bool` | `false` | Opt-in TLS (cert mounts + generated `tls.json` enabling the HTTPS API) |
| `tls_cert_path` | `string` | `""` | Host path to server cert (PEM); mounted at `/consul/tls/tls.crt` |
| `tls_key_path` | `string` | `""` | Host path to server key (PEM); mounted at `/consul/tls/tls.key` |
| `tls_ca_path` | `string` | `""` | Optional host path to CA cert (PEM); mounted at `/consul/tls/ca.crt` |

### TLS (optional)

TLS is **opt-in** and off by default (`tls_enabled = false`), so existing consumers run
unchanged as plaintext HTTP.

When `tls_enabled = true`:

- The supplied cert material is bind-mounted read-only at fixed container paths:
  - `tls_cert_path` → `/consul/tls/tls.crt`
  - `tls_key_path`  → `/consul/tls/tls.key`
  - `tls_ca_path`   → `/consul/tls/ca.crt` (only when a CA path is supplied)
- A generated `tls.json` is dropped into `config_path` and loaded from the config-dir. It sets
  `ports.https = 8501` and a `tls.defaults` stanza with `verify_incoming = false` and
  `verify_outgoing = true` when a CA is supplied (otherwise `false`).
- The HTTPS API is exposed on the host at `https_port` (default 8501).

**HTTP (8500) intentionally stays open during staging bring-up** so the `consul members`
healthcheck and initial bootstrap keep working. Hardening to HTTPS-only is a documented
follow-up.

`bind_address` defaults to `127.0.0.1` (localhost-only per NET-002); set it to `0.0.0.0`
only if Consul must be reachable on all host interfaces.


## Outputs

| Name | Description |
|---|---|
| `container_id` | Docker container ID |
| `container_name` | Container hostname on the network |
| `http_address` | Consul HTTP address from the host |
| `http_address_internal` | Consul HTTP address from containers on the same network |
| `dns_address` | Consul DNS address from the host |
| `datacenter` | Datacenter name |
