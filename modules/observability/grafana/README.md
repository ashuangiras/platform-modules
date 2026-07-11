# modules/observability/grafana

## What this module does

Deploys [Grafana](https://grafana.com) as a Docker container — the platform's metrics visualisation and dashboard layer. Grafana connects to Prometheus as its default data source and provides a web UI for building dashboards, exploring metrics, and configuring alerts.

## Why it exists

Prometheus stores metrics; Grafana makes them human-readable. Without dashboards:
- Operators cannot spot trends, only point-in-time values
- Alerting lacks context (no historical view of what "normal" looks like)
- SLO burn-rate tracking (REL-001) requires time-window visualisation

Grafana is the standard pairing with Prometheus and integrates directly with Consul service discovery, Loki for logs, and Tempo for traces when the platform grows.

## Why it was decided this way

**Grafana over alternatives** — Grafana is provider-agnostic, open-source, and has first-class Prometheus integration. It runs as a single container with no external database required for the initial SQLite storage backend.

**Prometheus pre-configured as default datasource via environment variable** — `GF_DATASOURCES_DEFAULT_*` env vars avoid a first-run manual configuration step and make the Prometheus connection declarative and reproducible.

**Admin password via env var (sensitive)** — The `admin_password` variable is marked `sensitive = true`. If left empty, Grafana's default `admin/admin` is used (development only). For production, inject from Vault.

## How it serves the platform

| Consumer | Usage |
|---|---|
| `platform-services/observability` | Deploys this module alongside Prometheus |
| Platform operators | Dashboard for Vault, Consul, MinIO, Prometheus, and service metrics |
| OBS-001 compliance | `/api/health` satisfies the health check requirement |
| REL-001 (future) | SLO burn-rate dashboards built on Prometheus recording rules |

## Usage

```hcl
module "grafana" {
  source = "git::https://github.com/ashuangiras/platform-modules.git//modules/observability/grafana?ref=main"

  container_name = "platform-grafana"
  data_path      = "/srv/platform/grafana/data"
  network_name   = module.networking.network_name
  prometheus_url = module.prometheus.http_address_internal

  admin_password = var.grafana_admin_password  # from Vault
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `container_name` | `string` | `"grafana"` | Container name |
| `image_tag` | `string` | `11.3.0` | Grafana image tag — pin to a specific release |
| `data_path` | `string` | required | Host path for data (writable by UID 472) |
| `http_port` | `number` | `3000` | Host port for UI |
| `network_name` | `string` | required | Docker network to attach to |
| `prometheus_url` | `string` | required | Prometheus URL (use internal address from `prometheus.http_address_internal`) |
| `admin_password` | `string` | `""` | Admin password (sensitive, from Vault) |
| `restart_policy` | `string` | `"unless-stopped"` | Docker restart policy |
| `labels` | `map(string)` | `{}` | Additional container labels |

## Outputs

| Name | Description |
|---|---|
| `container_id` | Docker container ID |
| `container_name` | Container hostname on the network |
| `http_address` | Grafana UI URL from the host |
| `http_address_internal` | Grafana URL from other containers |
| `health_endpoint` | Health check URL (`/api/health`) |
