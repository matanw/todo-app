APP_NAME ?= $(shell basename $(CURDIR))

# Load .env if it exists (init target creates it)
-include .env

PROJECT    := $(GCP_PROJECT_ID)
REGION     := $(or $(GCP_REGION),us-central1)
FUNCTION   := $(APP_NAME)

.PHONY: init login setup deploy dev destroy check-env check-gcloud

## Interactive setup: asks for Google Client ID and writes .env
init:
	@if [ -f .env ]; then echo ".env already exists — delete it and re-run to reset"; exit 0; fi
	@echo ""
	@echo "  Open this URL in your browser:"
	@echo "  https://console.cloud.google.com/apis/credentials?project=matan-app-zoo"
	@echo ""
	@echo "  → Create Credentials → OAuth 2.0 Client ID"
	@echo "  → Type: Web application"
	@echo "  → Authorised JavaScript origins: http://localhost:19006"
	@echo "  → Authorised redirect URIs:      http://localhost:19006"
	@echo "                                   https://auth.expo.io/@matanw/$(APP_NAME)"
	@echo ""
	@printf "Paste your Client ID: " && read CLIENT_ID && \
	printf 'GCP_PROJECT_ID=matan-app-zoo\nGCP_REGION=us-central1\nGOOGLE_CLIENT_ID=%s\nALLOWED_USERS=matanwis@gmail.com\nALLOW_ALL=false\nALLOW_DEVICE_AUTH=false\n' "$$CLIENT_ID" > .env && \
	echo "" && echo "✓ .env created. Run: make setup"

check-env:
	@test -n "$(PROJECT)"          || (echo "" && echo "ERROR: GCP_PROJECT_ID not set — run: make init" && echo "" && exit 1)
	@test -n "$(GOOGLE_CLIENT_ID)" || (echo "" && echo "ERROR: GOOGLE_CLIENT_ID not set — run: make init" && echo "" && exit 1)

check-gcloud:
	@command -v gcloud >/dev/null 2>&1 || { \
		echo ""; \
		echo "ERROR: gcloud is not installed."; \
		echo "  Install it: https://cloud.google.com/sdk/docs/install"; \
		echo "  Or via brew:  brew install --cask google-cloud-sdk"; \
		echo ""; \
		exit 1; \
	}
	@gcloud auth application-default print-access-token >/dev/null 2>&1 || { \
		echo ""; \
		echo "ERROR: GCP credentials not found. Run these two commands:"; \
		echo ""; \
		echo "  gcloud auth login"; \
		echo "  gcloud auth application-default login"; \
		echo ""; \
		echo "Then re-run: make setup"; \
		echo ""; \
		exit 1; \
	}

## Authenticate with GCP (run once per machine)
login:
	gcloud auth login
	gcloud auth application-default login
	@echo ""
	@echo "✓ Authenticated. Run: make setup"

## Provision GCP infrastructure (run once per app)
setup: check-env check-gcloud
	@echo "▶ Setting up [$(APP_NAME)] in project [$(PROJECT)]..."
	cd terraform && terraform init -upgrade
	cd terraform && terraform apply \
		-var="app_name=$(APP_NAME)" \
		-var="project_id=$(PROJECT)" \
		-var="region=$(REGION)"
	@echo ""
	@echo "✓ Infrastructure ready. Run: make deploy"

## Deploy the Cloud Function
deploy: check-env
	@echo "▶ Deploying Cloud Function [$(FUNCTION)]..."
	$(eval BUCKET := $(shell cd terraform && terraform output -raw bucket_name 2>/dev/null))
	$(eval SA     := $(shell cd terraform && terraform output -raw sa_email     2>/dev/null))
	@test -n "$(BUCKET)" || (echo "ERROR: Run 'make setup' first" && exit 1)
	gcloud functions deploy $(FUNCTION) \
		--gen2 \
		--runtime=python312 \
		--region=$(REGION) \
		--source=backend/ \
		--entry-point=handler \
		--trigger-http \
		--allow-unauthenticated \
		--service-account=$(SA) \
		--set-env-vars="BUCKET_NAME=$(BUCKET),APP_NAME=$(APP_NAME),GOOGLE_CLIENT_ID=$(GOOGLE_CLIENT_ID),ALLOWED_USERS=$(ALLOWED_USERS),ALLOW_ALL=$(ALLOW_ALL),ALLOW_DEVICE_AUTH=$(ALLOW_DEVICE_AUTH)" \
		--project=$(PROJECT)
	@echo ""
	@echo "✓ Function deployed:"
	@cd terraform && terraform output -raw function_url
	@echo ""

## Start Expo dev server (auto-writes frontend/.env.local)
dev: check-env
	$(eval FURL := $(shell cd terraform && terraform output -raw function_url 2>/dev/null || echo "http://localhost:8080"))
	@printf 'EXPO_PUBLIC_API_URL=%s\nEXPO_PUBLIC_APP_NAME=%s\nEXPO_PUBLIC_GOOGLE_CLIENT_ID=%s\n' \
		"$(FURL)" "$(APP_NAME)" "$(GOOGLE_CLIENT_ID)" > frontend/.env.local
	cd frontend && npm install --silent && ulimit -n 65536 && npx expo start --web --port 19006

## Tear down ALL infrastructure for this app (irreversible)
destroy: check-env
	@echo "⚠️  This will DELETE all [$(APP_NAME)] GCP resources and data!"
	@printf "Type the app name to confirm: " && read confirm && [ "$$confirm" = "$(APP_NAME)" ] || (echo "Aborted." && exit 1)
	cd terraform && terraform destroy \
		-var="app_name=$(APP_NAME)" \
		-var="project_id=$(PROJECT)" \
		-var="region=$(REGION)"
