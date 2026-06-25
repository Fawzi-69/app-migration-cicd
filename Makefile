# ===========================================================================
# Makefile — pilotage local (qualité, image, Terraform).
#
# Usage :
#   make quality                 # fmt + validate + tflint + checkov
#   make build                   # construit l'image conteneur
#   make plan   ENV=dev          # terraform plan d'un environnement
#   make apply  ENV=prod         # terraform apply
#   make destroy ENV=dev         # terraform destroy
#
# Variables (surchargées par l'environnement ou en ligne) :
#   ENV                dev | prod              (défaut: dev)
#   AWS_REGION         région AWS              (défaut: eu-west-3)
#   TF_STATE_BUCKET    bucket S3 de state      (backend partiel, obligatoire pour init)
#   TF_LOCK_TABLE      table DynamoDB de verrou
#   ECR_REPOSITORY_URL dépôt ECR cible du push
#   IMAGE_TAG          tag de l'image          (défaut: dev)
# ===========================================================================

ENV               ?= dev
AWS_REGION        ?= eu-west-3
TF_LOCK_TABLE     ?= app-migration-cicd-tf-locks
IMAGE_TAG         ?= dev
APP_DIR           := app
TF_DIR            := infra/terraform/environments/$(ENV)
BOOTSTRAP_DIR     := infra/terraform/bootstrap

# Arguments de backend partiel (aucun nom de compte en dur dans le code).
BACKEND_ARGS := \
	-backend-config="bucket=$(TF_STATE_BUCKET)" \
	-backend-config="dynamodb_table=$(TF_LOCK_TABLE)" \
	-backend-config="region=$(AWS_REGION)"

.DEFAULT_GOAL := help

# --- Garde-fou : ENV doit valoir dev ou prod -------------------------------
.PHONY: _check-env
_check-env:
	@case "$(ENV)" in dev|prod) ;; *) echo "ENV invalide '$(ENV)' (attendu: dev|prod)"; exit 1;; esac

# --- Aide -------------------------------------------------------------------
.PHONY: help
help:
	@echo "Cibles disponibles :"
	@echo "  quality            fmt + validate + tflint + checkov"
	@echo "  fmt | validate | lint | scan"
	@echo "  test               tests Go (via conteneur golang)"
	@echo "  build | push       image conteneur (push: ECR_REPOSITORY_URL requis)"
	@echo "  init  ENV=dev|prod terraform init (TF_STATE_BUCKET requis)"
	@echo "  plan  ENV=dev|prod"
	@echo "  apply ENV=dev|prod"
	@echo "  destroy ENV=dev|prod"
	@echo "  bootstrap-init | bootstrap-apply"

# ======================= Qualité (statique) ================================
.PHONY: quality fmt validate lint scan
quality: fmt validate lint scan

fmt:
	terraform fmt -recursive -check -diff

validate:
	@for d in $(BOOTSTRAP_DIR) infra/terraform/environments/dev infra/terraform/environments/prod; do \
		echo "==> validate $$d"; \
		terraform -chdir=$$d init -backend=false -input=false >/dev/null && \
		terraform -chdir=$$d validate; \
	done

lint:
	tflint --init >/dev/null
	tflint --recursive

scan:
	checkov -d . --config-file .checkov.yaml

# ======================= Application =======================================
.PHONY: test build push
test:
	docker run --rm -v "$(CURDIR)/$(APP_DIR)":/src -w /src golang:1.23-alpine \
		sh -c "go vet ./... && go test ./... -race -cover"

build:
	docker build -t app-migration-cicd:$(IMAGE_TAG) \
		--build-arg APP_VERSION=$(IMAGE_TAG) $(APP_DIR)

push: build
	@test -n "$(ECR_REPOSITORY_URL)" || { echo "ECR_REPOSITORY_URL requis"; exit 1; }
	aws ecr get-login-password --region $(AWS_REGION) \
		| docker login --username AWS --password-stdin $(ECR_REPOSITORY_URL)
	docker tag app-migration-cicd:$(IMAGE_TAG) $(ECR_REPOSITORY_URL):$(IMAGE_TAG)
	docker push $(ECR_REPOSITORY_URL):$(IMAGE_TAG)

# ======================= Terraform (environnements) ========================
.PHONY: init plan apply destroy
init: _check-env
	@test -n "$(TF_STATE_BUCKET)" || { echo "TF_STATE_BUCKET requis"; exit 1; }
	terraform -chdir=$(TF_DIR) init -input=false $(BACKEND_ARGS)

plan: _check-env
	terraform -chdir=$(TF_DIR) plan -input=false -var="image_tag=$(IMAGE_TAG)"

apply: _check-env
	terraform -chdir=$(TF_DIR) apply -input=false -var="image_tag=$(IMAGE_TAG)"

destroy: _check-env
	terraform -chdir=$(TF_DIR) destroy -input=false

# ======================= Bootstrap (une fois) ==============================
.PHONY: bootstrap-init bootstrap-apply
bootstrap-init:
	terraform -chdir=$(BOOTSTRAP_DIR) init -input=false

bootstrap-apply:
	terraform -chdir=$(BOOTSTRAP_DIR) apply -input=false
