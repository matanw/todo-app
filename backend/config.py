import os

# Google OAuth Client ID (required for Google token verification)
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")

# Who can use this app. Comma-separated emails.
ALLOWED_USERS = [u.strip() for u in os.getenv("ALLOWED_USERS", "matanwis@gmail.com").split(",") if u.strip()]

# Set ALLOW_ALL=true to skip user whitelist (useful during development)
ALLOW_ALL = os.getenv("ALLOW_ALL", "false").lower() == "true"

# Device ID auth: disabled by default.
# Device IDs are not cryptographically verified — enable only on trusted networks
# or for quick local testing. Never enable in production for shared apps.
ALLOW_DEVICE_AUTH = os.getenv("ALLOW_DEVICE_AUTH", "false").lower() == "true"

# GCP resources — injected by Cloud Function environment variables
BUCKET_NAME = os.getenv("BUCKET_NAME", "")
APP_NAME    = os.getenv("APP_NAME", "")
