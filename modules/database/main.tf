resource "time_sleep" "wait_for_vpc" {
  depends_on = [var.private_vpc_connection]

  create_duration = var.vpc_wait_duration
}

resource "google_sql_database_instance" "materialize" {
  depends_on = [time_sleep.wait_for_vpc]

  name             = "${var.prefix}-pg"
  database_version = var.db_version
  region           = var.region
  project          = var.project_id

  timeouts {
    create = "75m"
    update = "45m"
    delete = "45m"
  }

  settings {
    tier = var.tier

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 7
      }
    }

    maintenance_window {
      day          = 7
      hour         = 3
      update_track = "stable"
    }

    user_labels = var.labels
  }

  deletion_protection = false
}

resource "google_sql_database" "materialize" {
  name     = var.database_name
  instance = google_sql_database_instance.materialize.name
  project  = var.project_id

  deletion_policy = "ABANDON"
}

resource "google_sql_user" "materialize" {
  name     = var.database_user
  instance = google_sql_database_instance.materialize.name
  password = var.password
  project  = var.project_id

  deletion_policy = "ABANDON"
}
