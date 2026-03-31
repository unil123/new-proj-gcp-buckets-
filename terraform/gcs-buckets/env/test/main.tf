# Backend Configuration for Test Environment.
# The backend configuration is provided via GitHub Actions during terraform init.

terraform {
  backend "gcs" {
    # Configuration provided via init command:
    # terraform init \
    #   -backend-config="bucket=${GCS_BU_TASK_TEST_STATE_BUCKET}" \
    #   -backend-config="prefix=${GCS_BU_TASK_TEST_STATE_PREFIX}" \
  }
}