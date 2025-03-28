locals {
  version_ttl = (var.versioning && var.version_ttl != null) ? [{
    action = {
      type = "delete"
    }
    condition = {
      daysSinceNoncurrentTime = var.version_ttl
    }
  }] : []

  lifecycle_rules = concat(var.lifecycle_rules, local.version_ttl)

}

resource "google_storage_bucket" "materialize" {
  name          = "${var.prefix}-storage-${var.project_id}"
  location      = var.region
  project       = var.project_id
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = var.versioning
  }

  dynamic "lifecycle_rule" {
    for_each = local.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = lifecycle_rule.value.action.storage_class
      }
      condition {
        age                = lifecycle_rule.value.condition.age
        created_before     = lifecycle_rule.value.condition.created_before
        with_state         = lifecycle_rule.value.condition.with_state
        num_newer_versions = lifecycle_rule.value.condition.num_newer_versions
      }
    }
  }


  labels = var.labels
}

resource "google_storage_bucket_iam_member" "materialize_storage" {
  bucket = google_storage_bucket.materialize.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${var.service_account}"
}

resource "google_storage_hmac_key" "materialize" {
  project               = var.project_id
  service_account_email = var.service_account
}
