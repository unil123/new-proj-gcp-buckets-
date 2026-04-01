# Provider Configuration for Test Environment

provider "google" {
  project = local.config.project_id
  region  = local.config.location
}