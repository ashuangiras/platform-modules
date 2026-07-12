# modules/data/postgresql

## What this module does

Deploys a shared PostgreSQL 16 instance as a Docker container and provisions per-service databases and roles. Each service gets an isolated database and a limited-privilege owner role — no service can access another service's data.

## Why it exists

PostgreSQL is shared infrastructure. Running a separate PostgreSQL instance per service (as Authentik did previously with embedded database containers) wastes resources and multiplies operational burden. The correct pattern is one instance with database/role isolation per tenant.

This module handles both concerns atomically:
1. **Container**: deploys the PostgreSQL container
2. **Database provisioning**: uses the `cyrilgdn/postgresql` provider to create databases and roles while the container is running

## Why it was decided this way

**ADR-0020** (Identity Provider) established shared data infrastructure as a platform principle. The first consumer is Authentik; future consumers (task queues, audit logs, any stateful service) add one entry to the `databases` map — no new instance.

**Role isolation**: each service receives its own role with `CREATE`, `CONNECT`, and `TEMPORARY` privileges on its own database only. The superuser is not shared with application code.

**Credentials to Vault**: the `connections` output is sensitive. The calling configuration (`platform-infrastructure/integrations/`) writes each connection to Vault via `vault_kv_secret_v2`. Services read from Vault at runtime via Vault Agent — credentials never appear in container `env` blocks or config files.

## Usage

```hcl
module "postgresql" {
  source = "git::https://github.com/ashuangiras/platform-modules.git//modules/data/postgresql?ref=v1.1.0"

  container_name     = "platform-postgresql"
  data_path          = "/srv/platform/postgresql/data"
  network_name       = module.networking.network_name
  superuser_password = random_password.pg_superuser.result

  databases = {
    authentik = { password = random_password.pg_authentik.result }
    # future: grafana = { password = random_password.pg_grafana.result }
  }
}

# Write to Vault immediately (never leave credentials only in state)
resource "vault_kv_secret_v2" "pg_authentik" {
  mount     = "secret"
  name      = "platform/postgresql/databases/authentik"
  data_json = jsonencode(module.postgresql.connections["authentik"])
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `container_name` | `string` | `"postgresql"` | Container name |
| `image_tag` | `string` | `16.4-alpine` | PostgreSQL image tag |
| `data_path` | `string` | required | Host path for data |
| `port` | `number` | `5432` | Host port |
| `network_name` | `string` | required | Docker network |
| `superuser_password` | `string` | required | Superuser password (sensitive) |
| `databases` | `map(object)` | `{}` | Per-service `{ password }` map (sensitive) |
| `run_as_user` | `string` | `""` | Container user (empty = image default) |
| `bind_address` | `string` | `"127.0.0.1"` | Host IP the 5432 port binds to (localhost-only default, NET-002) |

### TLS (deferred)

Server-side TLS is **intentionally deferred** for this module. Postgres requires the server
private key to be owned by the DB user (UID 999) with `0600` permissions — which is unreliable
over macOS Docker Desktop bind mounts. Enabling it would additionally require `pg_hba` changes
(`hostssl`) and flipping the in-module `postgresql` provider from `sslmode = "disable"` to a
verifying mode.

The exposure is already mitigated: `bind_address` defaults to `127.0.0.1`, so the service is
bound to localhost only and is **not reachable on the LAN**. TLS remains a tracked follow-up.


## Outputs

| Name | Sensitive | Description |
|---|---|---|
| `container_name` | no | Container hostname on the network |
| `host` | no | Internal hostname for service-to-service connections |
| `host_address` | no | Host machine address |
| `port` | no | PostgreSQL port |
| `connections` | **yes** | Per-service `{ username, password, database, host, port, url }` — write to Vault |
