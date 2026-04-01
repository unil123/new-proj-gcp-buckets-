# Terraform and Provider Version Constraints
# GCS Buckets Business Unit Module

terraform {
  required_version = ">= 1.9.8"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}