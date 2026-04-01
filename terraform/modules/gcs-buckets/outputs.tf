# Outputs for GCS Buckets Business Unit Module

output "bucket_names" {
  description = "List of all created bucket names"
  value       = [for bucket in google_storage_bucket.buckets : bucket.name]
}

output "bucket_urls" {
  description = "Map of bucket names to their GS URLs"
  value = {
    for name, bucket in google_storage_bucket.buckets : name => bucket.url
  }
}

output "bucket_details" {
  description = "Detailed information about all created buckets"
  value = {
    for name, bucket in google_storage_bucket.buckets : name => {
      name                        = bucket.name
      location                    = bucket.location
      storage_class               = bucket.storage_class
      url                         = bucket.url
      self_link                   = bucket.self_link
      uniform_bucket_level_access = bucket.uniform_bucket_level_access
      public_access_prevention    = bucket.public_access_prevention
      versioning_enabled          = bucket.versioning[0].enabled
      labels                      = bucket.labels
    }
  }
}

output "iam_assignments" {
  description = "Summary of IAM role assignments"
  value = {
    for combo_key, iam_member in google_storage_bucket_iam_member.bucket_iam : combo_key => {
      bucket = iam_member.bucket
      role   = iam_member.role
      member = iam_member.member
    }
  }
}

output "environment_summary" {
  description = "High-level summary of the deployment"
  sensitive   = true
  value = {
    environment               = var.config.env
    project_id                = var.config.project_id
    project_name              = var.config.project_name
    location                  = var.config.location
    total_buckets             = length(local.all_buckets)
    total_iam_assignments     = length(google_storage_bucket_iam_member.bucket_iam)
    requirement_sets_deployed = length(var.config.requirement_sets)
  }
}