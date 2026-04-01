# Variables for GCS Buckets Business Unit Module

variable "config" {
  description = "Complete JSON configuration for GCS buckets provisioning"
  type = object({
    env          = string
    project_id   = string
    project_name = string
    location     = string
    defaults = object({
      storage_class               = string
      uniform_bucket_level_access = bool
      public_access_prevention    = string
      versioning_enabled          = bool
      soft_delete_retention_days  = number
    })
    global_roles         = optional(list(string), []) # Global roles applied to all buckets
    environment_roles    = optional(list(string), []) # Environment-specific roles
    default_bucket_roles = optional(list(string), []) # Default roles for buckets without explicit roles
    requirement_sets = list(object({
      set_id = string
      buckets = list(object({
        name               = string
        service_accounts   = list(string)          # Email addresses (service accounts, users, or groups)
        member_types       = optional(map(string)) # Optional explicit member types: {"email@domain.com": "user|group|serviceAccount"}
        versioning_enabled = optional(bool)
        roles              = optional(list(string))
        labels             = optional(map(string))
      }))
    }))
  })

  # Validation: Ensure every bucket has at least one service account
  validation {
    condition = alltrue([
      for req_set in var.config.requirement_sets : alltrue([
        for bucket in req_set.buckets : length(bucket.service_accounts) > 0
      ])
    ])
    error_message = "Every bucket must have at least one member (service account or user) assigned."
  }

  # Validation: If bucket-specific roles are provided, ensure they include all required roles
  validation {
    condition = alltrue([
      for req_set in var.config.requirement_sets : alltrue([
        for bucket in req_set.buckets : (
          bucket.roles == null ? true : alltrue([
            for required_role in concat(
              var.config.global_roles,
              var.config.environment_roles,
              var.config.default_bucket_roles
            ) :
            contains(bucket.roles, required_role)
          ])
        )
      ])
    ])
    error_message = "If bucket-specific roles are provided, they must include all required roles (global_roles + environment_roles + default_bucket_roles)."
  }

  # Validation: Ensure public access prevention is enforced
  validation {
    condition     = var.config.defaults.public_access_prevention == "enforced"
    error_message = "Public access prevention must be set to 'enforced' for security compliance."
  }

  # Validation: Ensure uniform bucket level access is enabled
  validation {
    condition     = var.config.defaults.uniform_bucket_level_access == true
    error_message = "Uniform bucket level access must be enabled for security compliance."
  }

  # Validation: Ensure supported storage class
  validation {
    condition = contains([
      "STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"
    ], var.config.defaults.storage_class)
    error_message = "Storage class must be one of: STANDARD, NEARLINE, COLDLINE, ARCHIVE."
  }

  # Validation: Ensure location is provided
  validation {
    condition     = length(var.config.location) > 0
    error_message = "Location must be specified and cannot be empty."
  }

  # Validation: Ensure soft delete retention is reasonable
  validation {
    condition = (
      var.config.defaults.soft_delete_retention_days >= 1 &&
      var.config.defaults.soft_delete_retention_days <= 90
    )
    error_message = "Soft delete retention days must be between 1 and 90 days."
  }

  # Validation: Ensure project_name is not empty after trimming
  validation {
    condition     = length(trimspace(var.config.project_name)) > 0
    error_message = "Project name must not be empty or contain only whitespace."
  }

  # Validation: Ensure project_name contains at least one valid character
  validation {
    condition     = can(regex("[a-zA-Z0-9]", var.config.project_name))
    error_message = "Project name must contain at least one letter or number."
  }
}