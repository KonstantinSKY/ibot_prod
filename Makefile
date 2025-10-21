# ==========================================================
# 🧱 iBot lightweight build & deploy Makefile
# ==========================================================

include .env
export

PROJECT_NAME    := ibot
DATE_TAG        := $(shell date +%F_%H-%M-%S)

# --- Paths ---
BUILD_DIR       := build
DEPLOY_DIR      := $(HOME)/Work/Deploys/$(PROJECT_NAME)_prod
DEPLOY_BACKUP   := $(DEPLOY_DIR)/backups

# --- Tools ---
ZIGBUILD        := cargo zigbuild --release
RUST_TARGET     := target
MKDIR_P         := mkdir -p

# ==========================================================
# 🧩 HELP
# ==========================================================
.PHONY: help
help h:
	@echo "🛠  Commands:"
	@echo "  make b       – build binaries for all platforms"
	@echo "  make d       – deploy binaries to $(DEPLOY_DIR)"
	@echo "  make r-lnx   – run Linux binary from build/"
	@echo "  make r-mac   – run macOS Intel binary from build/"
	@echo "  make r-arm   – run macOS ARM binary from build/"
	@echo "  make clean   – remove build artifacts"
	@echo "  make p / push - push all changes to GitHub"
	@echo "  make h       – show this help"

# ==========================================================
# 🔨 BUILD
# ==========================================================
.PHONY: build b
b build:
	@echo "🔨 Building $(PROJECT_NAME) for all platforms..."
	@$(MKDIR_P) $(BUILD_DIR)

	@echo "🐧 Linux x86_64..."
	@$(ZIGBUILD) --target x86_64-unknown-linux-gnu \
	&& cp $(RUST_TARGET)/x86_64-unknown-linux-gnu/release/$(PROJECT_NAME) $(BUILD_DIR)/$(PROJECT_NAME)-linux-x86_64 \
	&& echo "✅ Linux build done" \
	|| echo "⚠️ Linux build failed"

	@echo "🍎 macOS Intel..."
	@$(ZIGBUILD) --target x86_64-apple-darwin \
	&& cp $(RUST_TARGET)/x86_64-apple-darwin/release/$(PROJECT_NAME) $(BUILD_DIR)/$(PROJECT_NAME)-mac-intel \
	&& echo "✅ macOS Intel build done" \
	|| echo "⚠️ macOS Intel build failed"

	@echo "🍏 macOS ARM..."
	@$(ZIGBUILD) --target aarch64-apple-darwin \
	&& cp $(RUST_TARGET)/aarch64-apple-darwin/release/$(PROJECT_NAME) $(BUILD_DIR)/$(PROJECT_NAME)-mac-arm64 \
	&& echo "✅ macOS ARM build done" \
	|| echo "⚠️ macOS ARM build failed"

	@echo "🎯 Build complete. Binaries are in $(BUILD_DIR):"
	@ls -lh $(BUILD_DIR)

# ==========================================================
# 🚀 DEPLOY
# ==========================================================
.PHONY: deploy d
d deploy:
	@echo "🚀 Deploying $(PROJECT_NAME) → $(DEPLOY_DIR)"
	@$(MKDIR_P) $(DEPLOY_DIR) $(DEPLOY_BACKUP)

	# @echo "📦 Backing up existing binaries..."
	# @if [ -d "$(DEPLOY_DIR)" ]; then \
	# 	cp -R $(DEPLOY_DIR) $(DEPLOY_BACKUP)/$(DATE_TAG); \
	# 	echo "🗂  Backup saved to $(DEPLOY_BACKUP)/$(DATE_TAG)"; \
	# fi

	@echo "🔨 Building fresh binaries..."
	@$(MAKE) b

	@echo "📁 Copying new binaries to deploy directory..."
	cp $(BUILD_DIR)/$(PROJECT_NAME)-* $(DEPLOY_DIR)/
	chmod +x $(DEPLOY_DIR)/$(PROJECT_NAME)-*

	@echo "📁 Copying .env file..."
	cp .env $(DEPLOY_DIR)/.env

	@echo "📁 Copying  Makefile..."
		cp Makefile $(DEPLOY_DIR)/Makefile

	@$(MAKE) p

	@echo "✅ Deploy complete!"

# ==========================================================
# ▶️ RUNNERS
# ==========================================================
.PHONY: run-linux run-mac run-arm r-lnx r-mac r-arm
r-lnx run-linux:
	@echo "▶️  Running Linux build..."
	@$(BUILD_DIR)/$(PROJECT_NAME)-linux-x86_64

r-mac run-mac:
	@echo "▶️  Running macOS Intel build..."
	@$(BUILD_DIR)/$(PROJECT_NAME)-mac-intel

r-arm run-arm:
	@echo "▶️  Running macOS ARM build..."
	@$(BUILD_DIR)/$(PROJECT_NAME)-mac-arm64

# ==========================================================
# 🧹 CLEAN
# ==========================================================
.PHONY: clean
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(RUST_TARGET)
	@echo "✅ Clean done."


# ==========================================================
# 📤 AUTO PUSH TO GITHUB (optional)
# ==========================================================
.PHONY: push p
p push:
	@echo "🌐 Syncing $(DEPLOY_DIR) → GitHub..."
	@if [ ! -d "$(DEPLOY_DIR)/.git" ]; then \
		echo "❌ No git repo in $(DEPLOY_DIR). Run 'git init' there first."; \
		exit 1; \
	fi

	cd $(DEPLOY_DIR) && \
	git add . && \
	git commit -m "Auto deploy $(DATE_TAG)" || echo "ℹ️ Nothing new to commit" && \
	git push origin main && \
	echo "✅ Pushed successfully to GitHub."
