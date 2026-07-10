# modules/storage/minio

## What this module does

Deploys a [MinIO](https://min.io) instance as a Docker container providing an S3-compatible object storage API on the local platform host. The container binds a host directory for persistent data, exposes the S3 API and web console on configurable ports, and runs as a non-root user.

## Why it exists

**ADR-0014** (Terraform State Backend) ratified S3-compatible object storage as the Terraform state backend for `platform-infrastructure`. MinIO is the designated self-hosted implementation — it is binary-compatible with the AWS S3 API, meaning any tool that speaks S3 can use MinIO without modification.

The platform also requires a general-purpose durable object store for artifacts, backups, and evidence bundles. MinIO serves as that store, eliminating the need for external cloud storage and keeping all data on the platform operator's own hardware.

## Why it was decided this way

**Platform Principle P8** requires Terraform/OpenTofu as the execution model. Running MinIO as a Docker container managed by the `kreuzwerker/docker` Terraform provider means the deployment is declared, plan-reviewable (IAC-002), and idempotent.

**ADR-0014 bootstrap path**: The ADR originally described a cloud S3 bucket as a transitional first step. This module implements the self-hosted target state directly, removing the cloud dependency. The `backend "s3"` configuration in `platform-infrastructure` points to this MinIO instance with `endpoint = "http://localhost:9000"`.

**BAK-001** requires backup of stateful services. The `data_path` variable binds a host directory into the container. The operator is responsible for backing up that directory; the module enforces the path is declared (not auto-created inside the container's ephemeral layer).

## How it serves the platform

| Consumer | Usage |
|---|---|
| `platform-infrastructure` | Terraform state backend: `backend "s3"` → MinIO (`endpoint = "http://localhost:9000"`) |
| `platform-infrastructure` | Evidence bundle storage for compliance assessments |
| Future services | General-purpose S3-compatible object storage |

## Usage

```hcl
module "minio" {
  source = "git::https://github.com/ashuangiras/platform-modules.git//modules/storage/minio?ref=v1.0.0"

  container_name = "platform-minio"
  data_path      = "/srv/platform/minio/data"
  network_name   = module.platform_network.name

  root_user     = var.minio_root_user     # injected from Vault
  root_password = var.minio_root_password # injected from Vault
}
```

> **Security**: `root_user` and `root_password` are marked `sensitive`. Never set them as literals in `.tf` files — read them from Vault or pass them via a `terraform.tfvars` file that is excluded from git (enforced by `.gitignore` in `platform-infrastructure`).

## State backend configuration

Once MinIO is running, configure the Terraform backend in `platform-infrastructure`:

```hcl
terraform {
  backend "s3" {
    bucket                      = "platform-terraform-state"
    key                         = "platform-infrastructure/terraform.tfstate"
    region                      = "us-east-1"   # required by the S3 provider; value is ignored by MinIO
    endpoint                    = "http://localhost:9000"
    access_key                  = "<minio-access-key>"
    secret_key                  = "<minio-secret-key>"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `container_name` | `string` | `"minio"` | Docker container name |
| `image_tag` | `string` | `RELEASE.2024-11-07T00-52-20Z` | MinIO image tag — pin to a specific release |
| `data_path` | `string` | required | Host path for persistent data |
| `api_port` | `number` | `9000` | Host port for S3 API |
| `console_port` | `number` | `9001` | Host port for web console |
| `root_user` | `string` | required | Admin username (sensitive) |
| `root_password` | `string` | required | Admin password, ≥8 chars (sensitive) |
| `network_name` | `string` | required | Docker network to attach to |
| `restart_policy` | `string` | `"unless-stopped"` | Docker restart policy |
| `labels` | `map(string)` | `{}` | Additional container labels |

## Outputs

| Name | Description |
|---|---|
| `container_id` | Docker container ID |
| `container_name` | Container hostname on the network |
| `api_endpoint` | S3 API URL (`http://localhost:<api_port>`) |
| `console_url` | Web console URL |
| `volume_name` | Docker volume name for the data directory |
