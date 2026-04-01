# GCS Buckets Business Unit Terraform Module
# Provisions multiple GCS buckets with secure IAM assignments
# Supports JSON-driven configuration for additive provisioning

# Parse the JSON configuration
locals {
  # Flatten all requirement sets into a single list of buckets with project info
  all_buckets = flatten([
    for req_set in var.config.requirement_sets : [
      for bucket in req_set.buckets : merge(bucket, {
        set_id = req_set.set_id
        # Use requirement set project_id if specified, otherwise fall back to main config
        project_id   = try(req_set.project_id, var.config.project_id)
        project_name = try(req_set.project_name, var.config.project_name)
        # Merge requirement set defaults with global defaults (req_set takes precedence)
        defaults = merge(var.config.defaults, try(req_set.defaults, {}))
        # Remove unsupported attributes to prevent Terraform errors
        cleaned_defaults = {
          for k, v in merge(var.config.defaults, try(req_set.defaults, {})) : k => v
          if k != "hierarchical_namespace" # Filter out unsupported attribute
        }
      })
    ]
  ])

  # Create a map of buckets for easier access
  buckets_map = {
    for bucket in local.all_buckets : bucket.name => bucket
  }

  # Flatten bucket-member pairs for IAM assignments
  bucket_sa_pairs = flatten([
    for bucket in local.all_buckets : [
      for sa in bucket.service_accounts : {
        bucket_name     = bucket.name
        service_account = sa
        bucket_config   = bucket
      }
    ]
  ])

  # Flatten bucket-member-role combinations for IAM assignments
  bucket_sa_role_combinations = flatten([
    for pair in local.bucket_sa_pairs : [
      for role in coalesce(
        pair.bucket_config.roles,
        concat(
          try(var.config.global_roles, []),
          var.config.environment_roles,
          var.config.default_bucket_roles
        )
        ) : {
        bucket_name     = pair.bucket_name
        service_account = pair.service_account
        role            = role
        key             = "${pair.bucket_name}-${pair.service_account}-${role}"
      }
    ]
  ])
}

# Create GCS buckets
resource "google_storage_bucket" "buckets" {
  for_each = nonsensitive(local.buckets_map)

  name     = each.value.name
  location = var.config.location
  project  = each.value.project_id

  # Storage configuration
  storage_class               = each.value.cleaned_defaults.storage_class
  uniform_bucket_level_access = each.value.cleaned_defaults.uniform_bucket_level_access
  public_access_prevention    = each.value.cleaned_defaults.public_access_prevention

  # Note: hierarchical_namespace is configured via JSON but filtered out in Terraform
  # This preserves application requirements while avoiding provider errors

  # Soft delete configuration (enabled by default with configurable retention)
  soft_delete_policy {
    retention_duration_seconds = coalesce(
      each.value.cleaned_defaults.soft_delete_retention_days,
      7 # Default to 7 days if not specified
    ) * 24 * 60 * 60
  }

  # Versioning configuration (per bucket override or default)
  versioning {
    enabled = coalesce(each.value.versioning_enabled, each.value.cleaned_defaults.versioning_enabled)
  }

  # Labels
  labels = merge(
    {
      environment = var.config.env
      managed_by  = "terraform"
      project     = substr(lower(replace(replace(replace(trimspace(each.value.project_name), " ", "-"), "_", "-"), "/[^a-z0-9-]/", "")), 0, 63)
    },
    coalesce(each.value.labels, {})
  )

  # Lifecycle protection
  lifecycle {
    prevent_destroy = true
  }
}

# IAM assignments - Grant required roles to service accounts, users, and groups
resource "google_storage_bucket_iam_member" "bucket_iam" {
  for_each = nonsensitive({
    for combo in local.bucket_sa_role_combinations : combo.key => combo
  })

  bucket = google_storage_bucket.buckets[each.value.bucket_name].name
  role   = each.value.role
  member = (
    # Check if explicit member type is specified in bucket config
    try(local.buckets_map[each.value.bucket_name].member_types[each.value.service_account], null) != null ?
    "${local.buckets_map[each.value.bucket_name].member_types[each.value.service_account]}:${each.value.service_account}" :
    # Auto-detect member type based on email patterns
    # Service Account: ends with .iam.gserviceaccount.com or .gserviceaccount.com
    can(regex("\\.iam\\.gserviceaccount\\.com$|\\.gserviceaccount\\.com$", each.value.service_account)) ? "serviceAccount:${each.value.service_account}" :
    # Google Group: Enhanced patterns to catch more group variations
    can(regex("^grp-", lower(each.value.service_account))) ? "group:${each.value.service_account}" :
    can(regex("-grp-", lower(each.value.service_account))) ? "group:${each.value.service_account}" :
    can(regex("^group", lower(each.value.service_account))) ? "group:${each.value.service_account}" :
    can(regex("groups?@", lower(each.value.service_account))) ? "group:${each.value.service_account}" :
    can(regex("^(all|everyone|team|admin|admins|dev|developers|qa|test|prod|production|engineering|support)@", lower(each.value.service_account))) ? "group:${each.value.service_account}" :
    # Default: User account (covers individual email addresses)
    "user:${each.value.service_account}"
  )

  depends_on = [google_storage_bucket.buckets]
}