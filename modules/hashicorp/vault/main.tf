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

  command = ["vault", "server", "-config=/vault/config"]

  env = [
    "VAULT_LOG_LEVEL=${var.vault_log_level}",
    "VAULT_ADDR=http://0.0.0.0:${var.api_port}",
  ]

  ports {
    internal = var.api_port
    external = var.api_port
  }

  ports {
    internal = var.cluster_port
    external = var.cluster_port
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

  networks_advanced {
    name = var.network_name
  }

  healthcheck {
    test         = ["CMD", "vault", "status", "-address=http://127.0.0.1:${var.api_port}"]
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
      export VAULT_ADDR="http://127.0.0.1:${var.api_port}"
      KEYS_FILE=$(eval echo "${var.keys_path}")
      mkdir -p "$(dirname "$KEYS_FILE")"

      echo "[vault-unseal] Waiting for Vault at $VAULT_ADDR ..."
      for i in $(seq 1 30); do
        STATUS=$(vault status -format=json 2>/dev/null || true)
        [ -n "$STATUS" ] && break
        [ "$i" -eq 30 ] && echo "[vault-unseal] ERROR: Vault did not respond after 60s" >&2 && exit 1
        sleep 2
      done

      INITIALIZED=$(vault status -format=json 2>/dev/null | jq -r '.initialized')
      if [ "$INITIALIZED" = "false" ]; then
        echo "[vault-unseal] Initializing Vault (1-of-1 key share)..."
        vault operator init \
          -key-shares=1 \
          -key-threshold=1 \
          -format=json > "$KEYS_FILE"
        chmod 600 "$KEYS_FILE"
        echo "[vault-unseal] Initialized. Keys written to $KEYS_FILE"
      fi

      SEALED=$(vault status -format=json 2>/dev/null | jq -r '.sealed')
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
