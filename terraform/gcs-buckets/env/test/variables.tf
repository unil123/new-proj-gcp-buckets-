# Variable Definitions for Test Environment

variable "gcs_bu_task_test_json" {
  description = "JSON configuration for test environment GCS buckets"
  type        = string
  sensitive   = true
}