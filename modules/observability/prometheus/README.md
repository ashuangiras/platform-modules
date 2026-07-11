# modules/observability/prometheus

## What this module does

Deploys [Prometheus](https://prometheus.io) as a Docker container — the platform's primary metrics collection and alerting engine. Prometheus scrapes metrics from all platform services (Vault, Consul, MinIO, Grafana, and any service registered in Consul) and stores them in a local TSDB.

## Why it exists

The platform's observability posture requires health monitoring of all services (OBS-001). Prometheus provides:
- **Time-series metrics** for all platform components
- **Health check scraping** — detects service degradation before users do
- **Alerting** — fires alerts when services breach SLO targets (REL-001)

Without Prometheus, there is no basis for SLO definition, no detection of infrastructure drift, and no evidence for OBS controls.

## Why it was decided this way

**Prometheus over push-based systems** — Prometheus pulls metrics from targets on a configurable interval. This aligns with the platform's declarative, pull-based philosophy (P8 — Terraform manages desired state; Prometheus observes actual state). The scrape config lives as code alongside the services it observes.

**Retained on the platform** — Prometheus runs as a container on `platform-infrastructure` rather than as a managed cloud service. This preserves the self-hosted principle and ensures metrics are not exfiltrated to external systems.

**`--web.enable-lifecycle`** — Allows configuration reload via `POST /-/reload` without restarting the container. This is required for the Consul-based service discovery integration where new services register themselves.

## How it serves the platform

| Consumer | Usage |
|---|---|
| `platform-services/observability` | Deploys this module as the metrics backend |
| Grafana (`modules/observability/grafana`) | Uses Prometheus as its data source |
| All platform services | Expose metrics on `/metrics`; Prometheus scrapes them |
| OBS-001 compliance | Health endpoint `/-/healthy` satisfies the health check requirement |
| REL-001 (future) | Prometheus recording rules define SLI measurements |

## Usage

```hcl
module "prometheus" {
  source = "git::https://github.com/ashuangiras/platform-modules.git//modules/observability/prometheus?ref=main"

  container_name = "platform-prometheus"
  config_path    = "/srv/platform/prometheus/config"
  data_path      = "/srv/platform/prometheus/data"
  network_name   = module.networking.network_name
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `container_name` | `string` | `"prometheus"` | Container name |
| `image_tag` | `string` | `v3.0.1` | Prometheus image tag — pin to a specific release |
| `config_path` | `string` | required | Host path containing `prometheus.yml` |
| `data_path` | `string` | required | Host path for TSDB data (writable by UID 65534) |
| `http_port` | `number` | `9090` | Host port for the HTTP API and UI |
| `network_name` | `string` | required | Docker network to attach to |
| `retention_time` | `string` | `"15d"` | TSDB retention period |
| `restart_policy` | `string` | `"unless-stopped"` | Docker restart policy |
| `labels` | `map(string)` | `{}` | Additional container labels |

## Outputs

| Name | Description |
|---|---|
| `container_id` | Docker container ID |
| `container_name` | Container hostname on the network |
| `http_address` | Prometheus URL from the host |
| `http_address_internal` | Prometheus URL from other containers |
| `health_endpoint` | Health check URL (`/-/healthy`) |
