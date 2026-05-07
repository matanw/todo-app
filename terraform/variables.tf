variable "app_name" {
  description = "App name used to namespace all GCP resources (lowercase, hyphens only)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}[a-z0-9]$", var.app_name))
    error_message = "Must be 3-22 chars: lowercase letters, digits, hyphens."
  }
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}
