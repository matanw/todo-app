APP_NAME ?= $(shell basename $(CURDIR))

# Load .env if it exists (init target creates it)
-include .env

PROJECT    := $(GCP_PROJECT_ID)
REGION     := $(or $(GCP_REGION),us-central1)
FUNCTION   := $(APP_NAME)
ZIP_PATH   := /tmp/$(APP_NAME)-fn.zip

.PHONY: init setup deploy dev destroy check-env

## Copy .env.example → .env (run this first)
init:
	@test -f .env && echo ".env already exists — edit it directly" || (cp .env.example .env && echo "✓ .env created — open it and fill in GOOGLE_CLIENT_ID")

check-env:
	@test -n "$(PROJECT)"        || (echo "ERROR: GCP_PROJECT_ID not set in .env" && exit 1)
	@test -n "$(GOOGLE_CLIENT_ID)" || (echo "ERROR: GOOGLE_CLIENT_ID not set in .env" && exit 1)

## Provision GCP infrastructure (run once per app)
setup: check-env
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
	cd backend && zip -r $(ZIP_PATH) . -x "*.pyc" -x "__pycache__/*" -x "*.zip"
	gcloud functions deploy $(FUNCTION) \
		--gen2 \
		--runtime=python312 \
		--region=$(REGION) \
		--source=$(ZIP_PATH) \
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
	cd frontend && npm install --silent && npx expo start --web

## Tear down ALL infrastructure for this app (irreversible)
destroy: check-env
	@echo "⚠️  This will DELETE all [$(APP_NAME)] GCP resources and data!"
	@printf "Type the app name to confirm: " && read confirm && [ "$$confirm" = "$(APP_NAME)" ] || (echo "Aborted." && exit 1)
	cd terraform && terraform destroy \
		-var="app_name=$(APP_NAME)" \
		-var="project_id=$(PROJECT)" \
		-var="region=$(REGION)"
