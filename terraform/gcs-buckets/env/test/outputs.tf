# Output Values for Test Environment

output "test_bucket_names" {
  description = "List of all created bucket names in test environment"
  value       = module.gcs_buckets_test.bucket_names
}

output "test_bucket_urls" {
  description = "Map of bucket names to their GS URLs in test environment"
  value       = module.gcs_buckets_test.bucket_urls
}

output "test_bucket_details" {
  description = "Detailed information about all created buckets in test environment"
  value       = module.gcs_buckets_test.bucket_details
  sensitive   = true
}

output "test_iam_assignments" {
  description = "Summary of IAM role assignments in test environment"
  value       = module.gcs_buckets_test.iam_assignments
  sensitive   = true
}

output "test_environment_summary" {
  description = "High-level summary of the test deployment"
  value       = module.gcs_buckets_test.environment_summary
  sensitive   = true
}