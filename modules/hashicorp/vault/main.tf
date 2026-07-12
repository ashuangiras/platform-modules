locals {
  vault_scheme = var.tls_enabled ? "https" : "http"
}

data "docker_registry_image" "vault" {
  name = "hashicorp/vault:${var.image_tag}"
}

resource "docker_image" "vault" {
  name          = data.docker_registry_image.vault.name
  pull_triggers = [data.docker_registry_image.vault.sha256_digest]
  keep_locally  = true
}

resource "docker_volume" "data" {
  name = "${var.container_name}-data"

  driver = "local"
  driver_opts = {
    type   = "none"
    device = var.data_path
    o      = "bind"
  }
}

resource "docker_volume" "config" {
  name = "${var.container_name}-config"

  driver = "local"
  driver_opts = {
    type   = "none"
    device = var.config_path
    o      = "bind"
  }
}

resource "docker_container" "vault" {
  name    = var.container_name
  image   = docker_image.vault.image_id
  restart = var.restart_policy

  memory     = var.memory_limit_mib
  cpu_shares = var.cpu_shares

  # Vault requires IPC_LOCK to prevent secrets being swapped to disk.
  # On macOS Docker Desktop, set drop_capabilities = [] and run_as_user = ""
  # to avoid capability restriction errors.
  dynamic "capabilities" {
    for_each = length(var.capabilities) > 0 || length(var.drop_capabilities) > 0 ? [1] : []
    content {
      add  = var.capabilities
      drop = var.drop_capabilities
    }
  }

  # Run as the vault user (UID 100) — non-root per RUN-001.
  # Set run_as_user = "" to use the image default (macOS Docker Desktop).
  user = var.run_as_user != "" ? var.run_as_user : null

  # The kreuzwerker/docker provider reads a `capabilities` block back from the
  # daemon even when none is declared (empty add/drop on macOS Docker Desktop),
  # producing a perpetual "forces replacement" diff, and auto-sets memory_swap
  # to the memory limit and reads it back as a perpetual in-place diff. Both
  # churn — and thus RE-SEAL — Vault on every apply. Ignoring the drift keeps the
  # already-running container stable across applies.
  lifecycle {
    ignore_changes = [capabilities, memory_swap]
  }

  command = ["vault", "server", "-config=/vault/config"]

  env = [
    "VAULT_LOG_LEVEL=${var.vault_log_level}",
    "VAULT_ADDR=${local.vault_scheme}://0.0.0.0:${var.api_port}",
  ]

  ports {
    internal = var.api_port
    external = var.api_port
    ip       = var.bind_address
  }

  ports {
    internal = var.cluster_port
    external = var.cluster_port
    ip       = var.bind_address
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/vault/data"
  }

  volumes {
    volume_name    = docker_volume.config.name
    container_path = "/vault/config"
    read_only      = true
  }

  # Audit log volume — only mounted when logs_path is set (SEC-014).
  dynamic "volumes" {
    for_each = var.logs_path != "" ? [1] : []
    content {
      host_path      = var.logs_path
      container_path = "/vault/logs"
    }
  }

  # TLS server certificate — mounted read-only at a fixed container path so the
  # operator-owned vault.hcl has a stable contract. Only mounted when TLS is on.
  dynamic "volumes" {
    for_each = var.tls_enabled ? [1] : []
    content {
      host_path      = var.tls_cert_path
      container_path = "/vault/tls/tls.crt"
      read_only      = true
    }
  }

  # TLS server private key — mounted read-only at a fixed container path.
  dynamic "volumes" {
    for_each = var.tls_enabled ? [1] : []
    content {
      host_path      = var.tls_key_path
      container_path = "/vault/tls/tls.key"
      read_only      = true
    }
  }

  # TLS CA certificate — optional; only mounted when a CA path is supplied.
  dynamic "volumes" {
    for_each = var.tls_enabled && var.tls_ca_path != "" ? [1] : []
    content {
      host_path      = var.tls_ca_path
      container_path = "/vault/tls/ca.crt"
      read_only      = true
    }
  }

  networks_advanced {
    name = var.network_name
  }

  healthcheck {
    test         = var.tls_enabled ? ["CMD", "vault", "status", "-address=https://127.0.0.1:${var.api_port}", "-tls-skip-verify"] : ["CMD", "vault", "status", "-address=http://127.0.0.1:${var.api_port}"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 5
    start_period = "10s"
  }

  labels {
    label = "platform.managed"
    value = "true"
  }

  labels {
    label = "platform.service"
    value = "vault"
  }

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ---------------------------------------------------------------------------
# Auto-init and auto-unseal
#
# Vault starts in a sealed state after every restart. This null_resource runs
# a local shell script (via the host vault CLI) that:
#   1. Waits until the Vault API is reachable.
#   2. Initialises Vault the first time (1-of-1 Shamir key) and writes the
#      unseal key + root token to var.keys_path.
#   3. Unseals Vault on every apply where the container ID changed (restart or
#      recreation).
#
# Re-triggers only when the container is replaced (new ID). Idempotent: already-
# unsealed Vault is detected and skipped.
#
# Security: var.keys_path contains plaintext secrets. Ensure the path is:
#   - Outside the git repository
#   - Readable only by the Terraform operator (chmod 600 is applied by the script)
#   - Backed up and rotated per your key-management policy
# ---------------------------------------------------------------------------
resource "null_resource" "vault_init_unseal" {
  triggers = {
    container_id = docker_container.vault.id
  }

  provisioner "local-exec" {
    # Expand ~ in keys_path using shell, create parent dir, then init/unseal.
    command = <<-SHELL
      set -euo pipefail
      export VAULT_ADDR="${local.vault_scheme}://127.0.0.1:${var.api_port}"
      ${var.tls_enabled ? "export VAULT_SKIP_VERIFY=true" : ""}
      KEYS_FILE=$(eval echo "${var.keys_path}")
      mkdir -p "$(dirname "$KEYS_FILE")"

      echo "[vault-unseal] Waiting for Vault at $VAULT_ADDR ..."
      for i in $(seq 1 30); do
        # vault status exits 0=unsealed, 2=sealed, 1=error — capture output; || true handles 2
        VAULT_STATUS=$(vault status -format=json 2>/dev/null || true)
        [ -n "$VAULT_STATUS" ] && break
        [ "$i" -eq 30 ] && echo "[vault-unseal] ERROR: Vault did not respond after 60s" >&2 && exit 1
        sleep 2
      done

      # Parse from the already-captured status (avoids second call with non-zero exit)
      VAULT_STATUS=$(vault status -format=json 2>/dev/null || true)
      INITIALIZED=$(echo "$VAULT_STATUS" | jq -r '.initialized')
      SEALED=$(echo "$VAULT_STATUS" | jq -r '.sealed')

      if [ "$INITIALIZED" = "false" ]; then
        echo "[vault-unseal] Initializing Vault (1-of-1 key share)..."
        vault operator init \
          -key-shares=1 \
          -key-threshold=1 \
          -format=json > "$KEYS_FILE"
        chmod 600 "$KEYS_FILE"
        echo "[vault-unseal] Initialized. Keys written to $KEYS_FILE"
        SEALED="true"
      fi

      if [ "$SEALED" = "true" ]; then
        if [ ! -f "$KEYS_FILE" ]; then
          echo "[vault-unseal] ERROR: Vault is sealed but $KEYS_FILE not found." >&2
          exit 1
        fi
        UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' "$KEYS_FILE")
        vault operator unseal "$UNSEAL_KEY" > /dev/null
        echo "[vault-unseal] Vault unsealed."
      else
        echo "[vault-unseal] Vault is already unsealed."
      fi
    SHELL
  }

  depends_on = [docker_container.vault]
}
