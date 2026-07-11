data "docker_registry_image" "postgresql" {
  name = "postgres:${var.image_tag}"
}

resource "docker_image" "postgresql" {
  name          = data.docker_registry_image.postgresql.name
  pull_triggers = [data.docker_registry_image.postgresql.sha256_digest]
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

resource "docker_container" "postgresql" {
  name    = var.container_name
  image   = docker_image.postgresql.image_id
  restart = var.restart_policy

  # Set to "" for image default (postgres runs as UID 999 internally via gosu)
  user = var.run_as_user != "" ? var.run_as_user : null

  env = [
    "POSTGRES_PASSWORD=${var.superuser_password}",
    "POSTGRES_USER=postgres",
    "PGDATA=/var/lib/postgresql/data/pgdata",
  ]

  ports {
    internal = 5432
    external = var.port
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/var/lib/postgresql/data"
  }

  networks_advanced {
    name = var.network_name
  }

  healthcheck {
    test         = ["CMD-SHELL", "pg_isready -U postgres"]
    interval     = "10s"
    timeout      = "5s"
    retries      = 5
    start_period = "10s"
  }

  labels {
    label = "platform.managed"
    value = "true"
  }

  labels {
    label = "platform.service"
    value = "postgresql"
  }

  labels {
    label = "platform.component"
    value = "data"
  }

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ── Per-service databases and roles ──────────────────────────────────────────
# The postgresql provider connects to the running container to create each
# service's isolated database and limited-privilege owner role.

provider "postgresql" {
  host            = "localhost"
  port            = var.port
  username        = "postgres"
  password        = var.superuser_password
  sslmode         = "disable"
  connect_timeout = 15

  # Wait for PostgreSQL to be healthy before managing databases
  # depends_on is handled by the container healthcheck
}

resource "postgresql_database" "services" {
  # Database names are not sensitive; use nonsensitive() so for_each can iterate
  # even when var.databases contains sensitive password values.
  for_each = nonsensitive(tomap({ for k, v in var.databases : k => v }))

  name              = each.key
  owner             = each.key
  template          = "template0"
  encoding          = "UTF8"
  lc_collate        = "en_US.utf8"
  lc_ctype          = "en_US.utf8"
  connection_limit  = 100
  allow_connections = true

  depends_on = [docker_container.postgresql]
}

resource "postgresql_role" "services" {
  for_each = nonsensitive(tomap({ for k, v in var.databases : k => v }))

  name     = each.key
  login    = true
  password = each.value.password

  depends_on = [docker_container.postgresql]
}

resource "postgresql_grant" "service_owner" {
  for_each = nonsensitive(tomap({ for k, v in var.databases : k => v }))

  database    = each.key
  role        = each.key
  schema      = "public"
  object_type = "database"
  privileges  = ["CREATE", "CONNECT", "TEMPORARY"]

  depends_on = [postgresql_database.services, postgresql_role.services]
}
