include .env
export

DUMP_FILE := $(PGDUMP_DIR)/$(POSTGRES_DB)_$(shell date +%F_%H-%M-%S).dump
BINARY := target/release/$(PROJECT_NAME)

DEPLOY_DIR := $(MAIN_DEPLOY_DIR)/$(PROJECT_NAME)
DEPLOY_BACKUP_DIR := $(DEPLOY_DIR)/backups
REMOTE_DIR := $(MAIN_MEGA_DEPLOY_DIR)/$(PROJECT_NAME)
DATE_TAG := $(shell date +%F_%H-%M-%S)

MEGA_MAKEFILE := $(HOME)/Configs/mega/Makefile

.PHONY: help up down restart backup restore-latest status logs list-dumps dump-path deploy run_d containers sync_db

help h :
	@echo "🛠  Makefile commands:"
	@echo "  make run              — Start the Bot with cargo"
	@echo "  make up               — Start the PostgreSQL container"
	@echo "  make down             — Stop the PostgreSQL container"
	@echo "  make restart          — Restart PostgreSQL"
	@echo "  make backup           — 📦 Create a binary dump into PGDUMP_DIR"
	@echo "  make restore-latest   — ♻️  Restore the latest dump"
	@echo "  make status           — Check PostgreSQL status (pg_isready)"
	@echo "  make logs             — Show container logs"
	@echo "  make list-dumps       — List all dumps"
	@echo "  make dump-path        — Show current PGDUMP_DIR path"
	@echo "  make deploy           — 🔧 Build and deploy binary with backups"
	@echo "  make run_d            — 🚀 Check containers and run deployed binary"
	@echo "  make containers       — 🩺 Check health of docker-compose containers"

up :
	docker-compose up -d

down d:
	docker-compose down

restart:
	docker-compose restart postgres

backup:
	@mkdir -p $(PGDUMP_DIR)
	@echo "📦 Creating binary dump → $(DUMP_FILE)"
	docker exec gasbuds-postgres pg_dump -U $(POSTGRES_USER) -Fc $(POSTGRES_DB) > $(DUMP_FILE)
	@echo "✅ Dump created: $(DUMP_FILE)"
	@echo "📏 Dump file size:"
	@du -h $(DUMP_FILE)
	@echo "📦 Total dump folder size ($(PGDUMP_DIR)):"
	@du -sh $(PGDUMP_DIR)

restore-latest:
	@LATEST=$$(ls -t $(PGDUMP_DIR)/*.dump 2>/dev/null | head -n1); \
	if [ -z "$$LATEST" ]; then echo "❌ No .dump files found in $(PGDUMP_DIR)"; exit 1; fi; \
	echo "♻️  Restoring from: $$LATEST"; \
	cat $$LATEST | docker exec -i gasbuds-postgres pg_restore -U $(POSTGRES_USER) -d $(POSTGRES_DB); \
	echo "✅ Restore completed."

status:
	@echo "🔍 Checking PostgreSQL status..."
	docker exec gasbuds-postgres pg_isready -U $(POSTGRES_USER)
	@echo "-------------------------------------------------------------------------------"
	@echo "📦 Full Mount info for /var/lib/postgresql/data:"
	@docker inspect gasbuds-postgres --format '{{ json .Mounts }}' | jq

logs:
	docker logs -f gasbuds-postgres

list-dumps:
	@echo "📂 Available dumps in: $(PGDUMP_DIR)"
	@ls -lh $(PGDUMP_DIR)/*.dump 2>/dev/null || echo "❌ No dumps found."

dump-path:
	@echo "📁 Current dump path: $(PGDUMP_DIR)"

run:
	@echo "🚀 Running gasbuds in release mode..."
	cargo run --release --bin gasbuds

kill:
	sudo lsof -t -i :3031 | xargs -r kill -9

sync_db: #TODO
	@echo "🔄 Verifying Mega login..."
	@mega-whoami >/dev/null 2>&1 || ( echo "🚫 You are not logged in. Run: mega-login"; exit 1 )

	@echo "📂 Local dump path:  $(PGDUMP_DIR)"
	@echo "🌐 Remote path in MEGA: $(MEGA_REMOTE_PATH)"

	@echo "🔍 Checking if remote folder exists in MEGA..."
	@mega-ls "$(PGDATA_MEGA_REMOTE_PATH)" >/dev/null 2>&1 || (echo "❌ Remote folder not found: $(PGDATA_MEGA_REMOTE_PATH)"; exit 1)

	@mega-sync "$(PGDUMP_DIR)" "$(PGDATA_MEGA_REMOTE_PATH)" || (echo "❌ mega-sync failed"; exit 1 )
	@echo "✅ Sync successfully configured."

	@echo "📋 Checking current sync connections:"
	@mega-sync | grep "$(PGDUMP_DIR)" || echo "⚠️  Sync not listed — check manually with: mega-sync"

mkdir:
	@echo "📁 Initializing PostgreSQL project directories for: $(PROJECT_NAME)"
	mkdir -p $(PGDATA_DIR) $(PGDUMP_DIR)
	ls -la "$(dir $(PGDATA_DIR))"

deploy:
	@echo "🚀 Deploying $(PROJECT_NAME) → $(DEPLOY_DIR)"
	@mkdir -p "$(DEPLOY_DIR)" "$(DEPLOY_BACKUP_DIR)"

	@echo "🔨 Building release binary..."
	@cargo build --release && echo "✅ Build succeeded" || (echo "❌ Build failed. Aborting deploy."; exit 1)

	@echo "📦 Trying to backup previous version..."
	@if [ -f "$(DEPLOY_DIR)/$(PROJECT_NAME)" ]; then \
		echo "🗂  Backup existing binary → backups/"; \
		cp "$(DEPLOY_DIR)/$(PROJECT_NAME)" "$(DEPLOY_BACKUP_DIR)/$(PROJECT_NAME)-rv-$(DATE_TAG)"; \
	fi

	@echo "📦 Copying binary to deploy folder..."
	cp "$(BINARY)" "$(DEPLOY_DIR)/"
	chmod +x "$(DEPLOY_DIR)/$(PROJECT_NAME)"

	@echo "📁 Copying .env (with backup)..."
	@if [ -f "$(DEPLOY_DIR)/.env" ]; then \
		echo "🗂  Backup existing .env → backups/"; \
		cp "$(DEPLOY_DIR)/.env" "$(DEPLOY_BACKUP_DIR)/.env-rv-$(DATE_TAG)"; \
	fi
	cp .env "$(DEPLOY_DIR)/.env"

	@echo "📁 Copying .gitignore (no backup)..."
	cp .gitignore "$(DEPLOY_DIR)/.gitignore" || true

	@echo "📁 Copying Makefile (with backup)..."
	@if [ -f "$(DEPLOY_DIR)/Makefile" ]; then \
		echo "🗂  Backup existing Makefile → backups/"; \
		cp "$(DEPLOY_DIR)/Makefile" "$(DEPLOY_BACKUP_DIR)/Makefile-rv-$(DATE_TAG)"; \
	fi
	cp Makefile "$(DEPLOY_DIR)/Makefile"

	@echo "📁 Copying Scripts/ directory..."
	@if [ -d scripts ]; then \
		mkdir -p "$(DEPLOY_DIR)/scripts"; \
		cp -R scripts/. "$(DEPLOY_DIR)/scripts/"; \
		echo "✅ Scripts copied"; \
	else \
		echo "ℹ️  No Scripts/ directory found, skipping"; \
	fi

	@echo "✅ Deploy complete!"

# ==== GitHub settings you can override ====
GH_OWNER        ?=              # например: your-org ; оставь пустым для личного аккаунта gh auth
VISIBILITY      ?= private      # private | public | internal (для org)
DEFAULT_BRANCH  ?= main

repo-init:
	@echo "🧱 Initializing repository (remote-first) $(PROD_REPO_NAME)…" \
	repo_name="$${PROD_REPO_NAME:-}"; \
	[ -n "$$repo_name" ] || (echo "❌ repo_name empty"; exit 1); \
	\
	# --- проверка наличия GitHub CLI
	if ! command -v gh >/dev/null 2>&1; then \
		echo "❌ GitHub CLI (gh) not found. Install: https://cli.github.com/"; \
		exit 1; \
	fi; \
	\
	# --- формируем полное имя репо для gh: owner/name или просто name
	if [ -n "$(GH_OWNER)" ]; then \
		repo_full="$(GH_OWNER)/$$repo_name"; \
	else \
		repo_full="$$repo_name"; \
	fi; \
	echo "📦 Repository name: $$repo_full (visibility: $(VISIBILITY))"; \
	\
	# --- проверка существования удалённого (делаем это СРАЗУ после gh check)
	if gh repo view "$$repo_full" >/dev/null 2>&1; then \
		echo "ℹ️  Remote repo exists on GitHub: $$repo_full"; \
	else \
		echo "🌐 Creating remote repo on GitHub: $$repo_full"; \
		gh repo create "$$repo_full" --$(VISIBILITY) -y >/dev/null || { echo "❌ gh repo create failed"; exit 1; }; \
		echo "✅ Remote created: $$repo_full"; \
	fi; \
	\
	# --- локальный git (после того как удалённый точно есть)
	if [ ! -d .git ]; then \
		git init -b $(DEFAULT_BRANCH) >/dev/null && echo "🌿 Initialized local git ($(DEFAULT_BRANCH))"; \
	else \
		echo "ℹ️  Local git already initialized"; \
	fi; \
	\
	# --- первый коммит, если есть, что коммитить
	git add .; \
	if git diff --cached --quiet; then \
		echo "ℹ️  Nothing to commit"; \
	else \
		git commit -m "Initial commit" >/dev/null && echo "✅ First commit created"; \
	fi; \
	\
	# --- настраиваем origin на только что проверенный/созданный репозиторий
	if git remote get-url origin >/dev/null 2>&1; then \
		echo "ℹ️  Remote 'origin' already set: $$(git remote get-url origin)"; \
	else \
		# prefer SSH; если хочешь HTTPS — замени строку ниже
		git remote add origin "git@github.com:$$repo_full.git"; \
		echo "🔗 origin → git@github.com:$$repo_full.git"; \
	fi; \
	\
	# --- пушим ветку (создаёт ветку на GitHub, если её ещё нет)
	echo "🚢 Pushing $(DEFAULT_BRANCH) → origin"; \
	git push -u origin $(DEFAULT_BRANCH) >/dev/null && echo "✅ Pushed to GitHub: $$repo_full ($(DEFAULT_BRANCH))"


containers:
	@echo "🔍 Checking docker-compose containers..."
	@containers=$$(docker-compose ps -q); \
	if [ -z "$$containers" ]; then \
		echo "⚠️  No containers found via docker-compose."; \
		exit 1; \
	fi; \
	echo "📋 Container statuses:"; \
	all_statuses=$$(docker inspect --format '{{.Name}} | State: {{.State.Status}} | Health: {{if .State.Health}}{{.State.Health.Status}}{{else}}(no healthcheck){{end}}' $$containers); \
	echo "$$all_statuses"; \
	not_running=$$(echo "$$all_statuses" | grep -v 'State: running' | grep -v 'Health: healthy'); \
	if [ -n "$$not_running" ]; then \
		echo "❌ Some containers are NOT healthy or running:"; \
		echo "$$not_running"; \
		exit 1; \
	else \
		echo "✅ All containers are running and healthy."; \
	fi

run_d:
	@echo "🔁 Starting deploy-run sequence..."
	@echo "🚀 Running deployed binary from $(DEPLOY_DIR)..."
	@$(DEPLOY_DIR)/$(PROJECT_NAME)

sync-deploy sd:
	@echo "🔁 Syncing deploy directory: $(DEPLOY_DIR) to remote MEGA directory: $(REMOTE_DIR) ..."
	@make -f $(MEGA_MAKEFILE) sync $(DEPLOY_DIR) $(REMOTE_DIR)
