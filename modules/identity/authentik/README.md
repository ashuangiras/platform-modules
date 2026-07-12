# modules/identity/authentik

## What this module does

Deploys Authentik (server + worker) as two Docker containers. Authentik is the platform's identity provider — it handles SSO via OIDC/OAuth2 for all platform services and provides a forward authentication proxy for services that don't natively support OIDC.

**This module does not deploy PostgreSQL or Redis.** It accepts external connection URLs as inputs. Use `modules/data/postgresql` and `modules/data/redis` to provision the database and cache, then pass their outputs here.

## Why it exists and why it is in platform-infrastructure

**ADR-0020** established Authentik as the platform identity provider. It lives in `platform-infrastructure` (not `platform-services`) because:
1. Services like Vault and MinIO need Authentik to be running before they can authenticate human operators
2. The OIDC integration between Authentik and Vault/MinIO is managed by Terraform in `platform-infrastructure/integrations/`
3. Authentik is a foundation dependency, not a business service

## Deployment order

```
data/ (PostgreSQL + Redis) → identity/ (this module) → integrations/ (OIDC wiring)
```

## Usage

```hcl
module "authentik" {
  source = "git::https://github.com/ashuangiras/platform-modules.git//modules/identity/authentik?ref=v1.1.0"

  container_name_prefix    = "platform-authentik"
  network_name             = module.networking.network_name
  secret_key               = random_password.authentik_secret_key.result
  database_url             = module.data.connections["authentik"].url
  redis_url                = module.redis.connections["authentik"].url
  bootstrap_admin_password = random_password.authentik_admin.result
}

# Write admin credentials to Vault immediately
resource "vault_kv_secret_v2" "authentik_admin" {
  mount = "secret"
  name  = "platform/authentik/admin"
  data_json = jsonencode({
    username = "akadmin"
    password = random_password.authentik_admin.result
    email    = "admin@platform.local"
  })
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `container_name_prefix` | `string` | `"authentik"` | Prefix for server + worker container names |
| `image_tag` | `string` | `2024.10.4` | Authentik image tag |
| `network_name` | `string` | required | Docker network |
| `http_port` / `https_port` | `number` | `9000` / `9443` | Host ports |
| `secret_key` | `string` | required | Django signing key (sensitive, 50+ chars) |
| `database_url` | `string` | required | PostgreSQL URL from `modules/data/postgresql` (sensitive) |
| `redis_url` | `string` | required | Redis URL from `modules/data/redis` (sensitive) |
| `bootstrap_admin_email` | `string` | `admin@platform.local` | Bootstrap admin email |
| `bootstrap_admin_password` | `string` | required | Bootstrap admin password (sensitive, written to Vault) |
| `error_reporting_enabled` | `bool` | `false` | Disable for air-gapped environments |
| `run_as_user` | `string` | `""` | Container user (empty = image default) |
| `bind_address` | `string` | `"127.0.0.1"` | Host IP the server ports bind to (localhost-only default, NET-002) |
| `tls_enabled` | `bool` | `false` | Opt-in: mount custom cert material into `/certs` on the server |
| `tls_cert_path` | `string` | `""` | Host path to server cert (PEM); mounted at `/certs/tls.crt` |
| `tls_key_path` | `string` | `""` | Host path to server key (PEM); mounted at `/certs/tls.key` |
| `tls_ca_path` | `string` | `""` | Optional host path to CA cert (PEM); mounted at `/certs/ca.crt` |

### TLS (optional)

Authentik already terminates TLS on 9443 using a bundled self-signed certificate, so by
default (`tls_enabled = false`) behavior is unchanged.

When `tls_enabled = true`, custom cert material is bind-mounted read-only into the **server**
container at Authentik's standard discovery dir `/certs`:

- `tls_cert_path` → `/certs/tls.crt`
- `tls_key_path`  → `/certs/tls.key`
- `tls_ca_path`   → `/certs/ca.crt` (only when a CA path is supplied)

Authentik's worker discovers certs placed in `/certs`. **Selecting the custom cert for the
default brand is a consumer / day-2 configuration step** (done via the Authentik admin UI or
the integrations provider). The worker has no exposed ports and is left unchanged.

`bind_address` defaults to `127.0.0.1` (localhost-only per NET-002); set it to `0.0.0.0`
only if Authentik must be reachable on all host interfaces.


## Outputs

| Name | Description |
|---|---|
| `server_container_name` | Authentik server hostname on the Docker network |
| `http_url` / `https_url` | Authentik URLs from the host |
| `internal_url` | URL for containers on the Docker network |
| `issuer_url` | OIDC issuer URL — use as `oidc_discovery_url` in Vault JWT auth and Grafana OAuth2 |
