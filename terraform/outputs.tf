output "bucket_name" {
  description = "App data bucket name"
  value       = google_storage_bucket.app_data.name
}

output "staging_bucket" {
  description = "Function source staging bucket"
  value       = google_storage_bucket.function_staging.name
}

output "sa_email" {
  description = "Cloud Function service account email"
  value       = google_service_account.function_sa.email
}

output "function_url" {
  description = "Expected Cloud Function URL after make deploy"
  value       = "https://${var.region}-${var.project_id}.cloudfunctions.net/${var.app_name}"
}
