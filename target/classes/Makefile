# ==============================
# Claims AME Automation Makefile
# ==============================
# Usage:
#   make up               # do everything for local/systemd OR docker compose (detects which one to use)
#   make systemd-up       # force systemd mode (VM)
#   make compose-up       # force docker compose mode
#   make seed             # seed facilities again (safe to repeat)
#   make rotate-key       # rotate AME key (after you prepare a new keystore/keyfile)
#   make k8s-seed         # seed facilities via a Kubernetes Job
#
# Variables you may set (env or CLI):
#   MODE=PKCS12|FILE                 (default PKCS12)
#   KS_PASS=Str0ngP@ssw0rd           (PKCS12 password; ignored in FILE mode)
#   KEYID=claims-ame.v1
#   APP_DIR=/opt/claims              (systemd VM)
#   ADMIN_URL=http://localhost:8080
#   ADMIN_TOKEN=<SUPER_ADMIN_BEARER_TOKEN>
#   FAC_FILE=./facilities.json
#   COMPOSE_FILE=docker-compose.yml
#   K8S_NAMESPACE=default
#
# Detect env:
SYSTEMD_EXISTS := $(shell command -v systemctl >/dev/null 2>&1 && echo yes || echo no)
COMPOSE_EXISTS := $(shell command -v docker-compose >/dev/null 2>&1 && echo yes || echo no)
DOCKER_EXISTS  := $(shell command -v docker >/dev/null 2>&1 && echo yes || echo no)

# Defaults
MODE      ?= PKCS12
KS_PASS   ?= Str0ngP@ssw0rd
KEYID     ?= claims-ame.v1
APP_DIR   ?= /opt/claims
ADMIN_URL ?= http://localhost:8080
FAC_FILE  ?= ./facilities.json
COMPOSE_FILE ?= docker-compose.yml
K8S_NAMESPACE ?= default

# Colors
GREEN=\033[0;32m
YELL=\033[1;33m
RED=\033[0;31m
NC=\033[0m

.PHONY: up systemd-up compose-up post-install systemd-post-install compose-post-install seed rotate-key k8s-seed k8s-rotate help

help:
	@echo "Targets:"
	@echo "  make up            - auto pick systemd or docker compose and run post-install + start + seed"
	@echo "  make systemd-up    - force systemd (VM) flow"
	@echo "  make compose-up    - force docker compose flow"
	@echo "  make seed          - seed facilities only (safe to re-run)"
	@echo "  make rotate-key    - re-encrypt rows after you swapped AME key file/keystore"
	@echo "  make k8s-seed      - run a Kubernetes Job to seed facilities"
	@echo "Variables:"
	@echo "  MODE=$(MODE) KS_PASS=**** KEYID=$(KEYID) APP_DIR=$(APP_DIR) ADMIN_URL=$(ADMIN_URL) FAC_FILE=$(FAC_FILE)"

up:
ifeq ($(SYSTEMD_EXISTS),yes)
	@echo "$(YELL)==> systemd detected; running systemd-up$(NC)"
	@$(MAKE) systemd-up
else ifeq ($(COMPOSE_EXISTS),yes)
	@echo "$(YELL)==> docker-compose detected; running compose-up$(NC)"
	@$(MAKE) compose-up
else ifeq ($(DOCKER_EXISTS),yes)
	@echo "$(YELL)==> docker detected but no docker-compose; using compose v2 if available$(NC)"
	@$(MAKE) compose-up
else
	@echo "$(RED)No systemd/docker-compose/docker found. Please choose a mode explicitly.$(NC)"
	exit 2
endif

# --------------------------
# Systemd VM flow
# --------------------------
systemd-up: systemd-post-install seed
	@echo "$(GREEN)All done (systemd).$(NC)"

systemd-post-install:
	@echo "$(YELL)==> AME post-install (systemd)$(NC)"
	@sudo mkdir -p $(APP_DIR)/config
ifeq ($(MODE),PKCS12)
	@if [ ! -f "$(APP_DIR)/config/claims.p12" ]; then \
	  echo "Generating PKCS12 keystore at $(APP_DIR)/config/claims.p12"; \
	  keytool -genseckey -alias claims-ame -keyalg AES -keysize 256 -storetype PKCS12 \
	    -keystore $(APP_DIR)/config/claims.p12 -storepass "$(KS_PASS)"; \
	else echo "Keystore exists"; fi
	@sudo mkdir -p /etc/systemd/system/claims.service.d
	@echo "[Service]\nEnvironment=CLAIMS_AME_STORE_PASS=$(KS_PASS)" | sudo tee /etc/systemd/system/claims.service.d/10-ame-env.conf >/dev/null
else ifeq ($(MODE),FILE)
	@if [ ! -f "$(APP_DIR)/config/ame.key" ]; then \
	  echo "Generating 32-byte key at $(APP_DIR)/config/ame.key"; \
	  openssl rand -out $(APP_DIR)/config/ame.key 32; chmod 600 $(APP_DIR)/config/ame.key; \
	else echo "Key file exists"; fi
else
	@echo "$(RED)MODE must be PKCS12 or FILE$(NC)"; exit 3
endif
	@echo "Ensure application.yml has claims.security.ame.enabled=true and keyId=$(KEYID)"
	@sudo systemctl daemon-reload || true
	@sudo systemctl restart claims.service || true
	@sleep 3; sudo journalctl -u claims -n 50 --no-pager || true

# --------------------------
# Docker Compose flow
# --------------------------
compose-up: compose-post-install
	@echo "$(YELL)==> Starting docker compose$(NC)"
	@CLAIMS_AME_STORE_PASS="$(KS_PASS)" docker compose -f $(COMPOSE_FILE) up -d
	@$(MAKE) seed
	@echo "$(GREEN)All done (compose).$(NC)"

compose-post-install:
	@echo "$(YELL)==> AME post-install (compose)$(NC)"
	@mkdir -p ./config
ifeq ($(MODE),PKCS12)
	@if [ ! -f "./config/claims.p12" ]; then \
	  echo "Generating PKCS12 keystore ./config/claims.p12"; \
	  keytool -genseckey -alias claims-ame -keyalg AES -keysize 256 -storetype PKCS12 \
	    -keystore ./config/claims.p12 -storepass "$(KS_PASS)"; \
	else echo "Keystore exists"; fi
	@echo "Ensure compose exports CLAIMS_AME_STORE_PASS=$(KS_PASS) and mounts ./config:/workspace/config:ro"
else ifeq ($(MODE),FILE)
	@if [ ! -f "./config/ame.key" ]; then \
	  echo "Generating 32-byte key ./config/ame.key"; \
	  openssl rand -out ./config/ame.key 32; chmod 600 ./config/ame.key; \
	else echo "Key file exists"; fi
	@echo "Ensure compose mounts ./config:/workspace/config:ro"
else
	@echo "$(RED)MODE must be PKCS12 or FILE$(NC)"; exit 3
endif

# --------------------------
# Seed facilities (shared)
# --------------------------
seed:
	@echo "$(YELL)==> Seeding facilities from $(FAC_FILE) to $(ADMIN_URL)$(NC)"
	@if [ -z "$(ADMIN_TOKEN)" ]; then echo "$(RED)ADMIN_TOKEN not set (SUPER_ADMIN bearer)$(NC)"; exit 4; fi
	@if [ ! -f "$(FAC_FILE)" ]; then \
	  echo "[\n  {\"facilityCode\":\"HOSP1\",\"facilityName\":\"City Hospital\",\"active\":true,"\
	       "\"endpointUrl\":\"https://qa.eclaimlink.ae/dhpo/ValidateTransactions.asmx\",\"soap12\":false,"\
	       "\"callerLicense\":\"LIC123\",\"ePartner\":\"EPART001\",\"login\":\"dhpo_user_hosp1\",\"password\":\"S3cureP@ss!\"}\n]" > $(FAC_FILE); \
	  echo "$(YELL)Sample facilities.json created at $(FAC_FILE). Edit and re-run 'make seed'.$(NC)"; exit 0; \
	fi
	@len=$$(jq 'length' $(FAC_FILE)); \
	for i in $$(seq 0 $$((len-1))); do \
	  body=$$(jq -c ".[$$i]" $(FAC_FILE)); \
	  code=$$(echo $$body | jq -r '.facilityCode'); \
	  echo " - upserting $$code"; \
	  http=$$(curl -s -o /tmp/fac.out -w "%{http_code}" -X POST "$(ADMIN_URL)/admin/facilities" \
	    -H "Content-Type: application/json" -H "Authorization: Bearer $(ADMIN_TOKEN)" -d "$$body"); \
	  if [ "$$http" != "200" ] && [ "$$http" != "204" ]; then \
	    echo "$(RED)   ERROR ($$http): $$(cat /tmp/fac.out)$(NC)"; exit 5; \
	  fi; \
	done
	@echo "$(GREEN)Facilities seeded.$(NC)"

# --------------------------
# Rotate AME key (after swapping keystore/key file + bump keyId in config)
# --------------------------
rotate-key:
	@echo "$(YELL)==> Rotating AME key via /admin/facilities/ame/rotate$(NC)"
	@if [ -z "$(ADMIN_TOKEN)" ]; then echo "$(RED)ADMIN_TOKEN not set$(NC)"; exit 4; fi
	@curl -s -X POST "$(ADMIN_URL)/admin/facilities/ame/rotate" \
	  -H "Authorization: Bearer $(ADMIN_TOKEN)" | tee /tmp/rotate.json
	@echo "\n$(GREEN)If rotate returns {\"updated\":0}, all rows are on the new key.$(NC)"

# --------------------------
# Kubernetes helpers (optional)
# --------------------------
k8s-seed:
	@echo "$(YELL)==> Applying seed job in namespace $(K8S_NAMESPACE)$(NC)"
	@kubectl -n $(K8S_NAMESPACE) apply -f k8s/seed-facilities-job.yaml
	@kubectl -n $(K8S_NAMESPACE) logs -l job-name=claims-seed-facilities --tail=100 --prefix=true
