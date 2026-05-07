terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  labels = {
    managed_by = "factory"
    app        = var.app_name
  }
}

resource "google_project_service" "apis" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "storage.googleapis.com",
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

resource "google_service_account" "function_sa" {
  account_id   = "${var.app_name}-fn"
  display_name = "${var.app_name} Cloud Function"
  depends_on   = [google_project_service.apis]
}

# App data bucket — each app gets its own isolated bucket
resource "google_storage_bucket" "app_data" {
  name                        = "${var.project_id}-${var.app_name}-data"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
  labels                      = local.labels

  versioning {
    enabled = true
  }
}

# Staging bucket for function source code uploads
resource "google_storage_bucket" "function_staging" {
  name                        = "${var.project_id}-${var.app_name}-staging"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  labels                      = merge(local.labels, { purpose = "staging" })
}

# Function SA can read/write only its own app data bucket
resource "google_storage_bucket_iam_member" "function_data_access" {
  bucket = google_storage_bucket.app_data.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.function_sa.email}"
}

# Function SA can write to its own staging bucket
resource "google_storage_bucket_iam_member" "function_staging_access" {
  bucket = google_storage_bucket.function_staging.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.function_sa.email}"
}
