# modules/data/redis

## What this module does

Deploys a shared Redis 7 instance with ACL-based per-service user isolation. Each service receives a dedicated ACL user with a scoped password, command set, and key prefix — no service can read or write another service's keys.

## Why it exists

Redis is shared cache/session infrastructure. Running a separate Redis per service is wasteful. The correct pattern is one instance with ACL isolation per tenant (Redis 7+ ACL support).

The module generates a `users.acl` file from the `acl_users` map, mounts it read-only into the container, and restarts the container whenever the ACL changes.

## Why it was decided this way

**ADR-0020**: shared data infrastructure with per-service isolation. Redis ACLs (introduced in Redis 6, mature in Redis 7) provide the right isolation level without running multiple instances.

**Default user disabled**: `user default off` is always the first ACL line. No anonymous or unauthenticated access is possible.

**Credentials to Vault**: the `connections` output is sensitive. The calling configuration writes each connection to Vault via `vault_kv_secret_v2`. Services read from Vault via Vault Agent — never from container env blocks.

## Usage

```hcl
module "redis" {
  source = "git::https://github.com/ashuangiras/platform-modules.git//modules/data/redis?ref=v1.1.0"

  container_name = "platform-redis"
  data_path      = "/srv/platform/redis/data"
  config_path    = "/srv/platform/redis/config"
  network_name   = module.networking.network_name
  admin_password = random_password.redis_admin.result

  acl_users = {
    authentik = {
      password   = random_password.redis_authentik.result
      commands   = "+@all"
      key_prefix = "authentik:*"
    }
  }
}

resource "vault_kv_secret_v2" "redis_authentik" {
  mount     = "secret"
  name      = "platform/redis/users/authentik"
  data_json = jsonencode(module.redis.connections["authentik"])
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `container_name` | `string` | `"redis"` | Container name |
| `image_tag` | `string` | `7.4-alpine` | Redis image tag (must be 7.x for ACL support) |
| `data_path` | `string` | required | Host path for AOF/RDB persistence |
| `config_path` | `string` | required | Host path for generated `users.acl` |
| `port` | `number` | `6379` | Host port |
| `network_name` | `string` | required | Docker network |
| `admin_password` | `string` | required | Admin ACL user password (sensitive) |
| `acl_users` | `map(object)` | `{}` | Per-service `{ password, commands, key_prefix }` (sensitive) |
| `run_as_user` | `string` | `""` | Container user (empty = image default) |

## Outputs

| Name | Sensitive | Description |
|---|---|---|
| `container_name` | no | Container hostname |
| `host` | no | Internal hostname |
| `port` | no | Redis port |
| `connections` | **yes** | Per-service `{ username, password, host, port, url }` — write to Vault |
