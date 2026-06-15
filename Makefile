STACKS_DIR  := stacks
VOLUMES_DIR := /mnt/docker-volumes
PUID        := 1000
PGID        := 1000
NETWORKS    := proxy bypass

.PHONY: all prepare networks deploy-% deploy-all clean-env

all: prepare networks deploy-all

prepare:
	@echo "Preparing base volumes directory"
	@sudo mkdir -p $(VOLUMES_DIR)
	@sudo chown $(PUID):$(PGID) $(VOLUMES_DIR)
	@sudo chmod 750 $(VOLUMES_DIR)

networks:
	@echo "Ensuring Docker networks exist"
	@for net in $(NETWORKS); do \
		docker network inspect $$net >/dev/null 2>&1 || docker network create $$net; \
	done

deploy-%: prepare networks
	@echo "Deploying $* stack"
	@if [ -f "$(STACKS_DIR)/$*/init.sh" ]; then \
		echo "    [INIT] Running stack init script"; \
		bash $(STACKS_DIR)/$*/init.sh; \
	fi	
	
	@if [ -f ".shared.sops.env" ]; then \
		echo "    [SOPS] Decrypting .shared.env"; \
		sops -d .shared.sops.env > .shared.env; \
	fi
	
	@echo "    [SOPS] Decrypting local files for $*"
	@find $(STACKS_DIR)/$* -type f -name "*.sops.*" -exec bash -c 'sops -d "$$0" > "$${0/.sops./.}"' {} \;
	
	@ENV_ARGS=""; \
	if [ -f ".shared.env" ]; then ENV_ARGS="$$ENV_ARGS --env-file ../../.shared.env"; fi; \
	if [ -f "$(STACKS_DIR)/$*/.env" ]; then ENV_ARGS="$$ENV_ARGS --env-file .env"; fi; \
	
	@echo "    [Docker] Starting containers"
	@cd $(STACKS_DIR)/$* && docker compose $$ENV_ARGS up -d --remove-orphans

deploy-all: target_stacks = $(shell ls $(STACKS_DIR))
deploy-all:
	@echo "Deploying all stacks..."
	@for stack in $(target_stacks); do \
		$(MAKE) deploy-$$stack; \
	done

clean-env:
	@echo "Cleaning decrypted files"
	@rm -f .shared.env
	@find $(STACKS_DIR) -name '.env' -type f -delete
	@# Add other specific unencrypted static configs here if needed
