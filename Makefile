XCODE   := $(shell bash scripts/xcode-dir.sh)
SWIFT   := DEVELOPER_DIR=$(XCODE) bash scripts/swift-env.sh
BUNDLE  := $(HOME)/Applications/Fala.app/Contents/MacOS/Fala
APP     := $(HOME)/Applications/Fala.app
HOOK    := .git/hooks/pre-commit
APPBUILD := bash scripts/build-app.sh

# ── Cores ──────────────────────────────────────────────────────────────────────
BOLD  := \033[1m
CYAN  := \033[36m
GREEN := \033[32m
GREY  := \033[2m
RESET := \033[0m

.DEFAULT_GOAL := help
.PHONY: help check lint test test-mlx hooks dev install kill logs logs-save clean release release-dry

help: ## Mostra este menu
	@printf "\n  $(BOLD)Fala$(RESET)\n\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; \
	         {printf "  $(CYAN)make %-10s$(RESET) %s\n", $$1, $$2}'
	@printf "\n"

# ── Targets ────────────────────────────────────────────────────────────────────

check: hooks lint test ## Preflight completo: hooks + lint + testes (roda antes de dev/install)

lint: ## Roda SwiftLint (--strict)
	@DEVELOPER_DIR=$(XCODE) swiftlint --strict

test: ## Roda os testes unitários (smoke MLX fica em make test-mlx)
	@printf "$(GREY)▶ swift test$(RESET)\n"
	@$(SWIFT) test

test-mlx: ## Roda smoke test do MLX no app empacotado
	@printf "$(GREY)▶ app bundle MLX smoke$(RESET)\n"
	@DEVELOPER_DIR=$(XCODE) bash scripts/test-mlx.sh

hooks: ## Instala git hooks (auto — no-op se já estiverem instalados)
	@[ -f "$(HOOK)" ] || bash scripts/install-hooks.sh

dev: check ## check → build debug → relança o app (PROFILE=0 para desabilitar timing logs)
	@printf "$(GREY)▶ xcodebuild (Debug)$(RESET)\n"
	@defaults write dev.fala.app ProfilingEnabled -bool $(if $(filter 0,$(PROFILE)),false,true)
	@$(APPBUILD) debug --open
	@printf "$(GREEN)✓ App relançado — verifique o menu bar$(RESET)\n"
	@if [ "$(PROFILE)" != "0" ]; then printf "$(GREY)  Profiling habilitado (use PROFILE=0 para desabilitar)$(RESET)\n"; fi
	@printf "$(GREY)  Para gravar logs em arquivo: make logs-save$(RESET)\n"

install: check ## check → build release → instala
	@printf "$(GREY)▶ xcodebuild (Release)$(RESET)\n"
	@defaults delete dev.fala.app ProfilingEnabled 2>/dev/null || true
	@$(APPBUILD) release --open
	@printf "$(GREEN)✓ Release instalado e rodando$(RESET)\n"

kill: ## Encerra o app
	@pkill Fala 2>/dev/null && printf "$(GREEN)✓ Fala encerrado$(RESET)\n" || printf "$(GREY)App não estava rodando$(RESET)\n"

logs: ## Mostra logs do app em tempo real (Ctrl+C para sair)
	@printf "$(GREY)Aguardando logs de Fala… (Ctrl+C para sair)$(RESET)\n"
	@log stream --predicate 'subsystem == "dev.fala.app"' --level debug --style syslog

logs-save: ## Grava logs em ~/Desktop/fala-logs/ e exibe em tempo real (Ctrl+C para parar)
	@mkdir -p "$(HOME)/Desktop/fala-logs"
	@LOG_FILE="$(HOME)/Desktop/fala-logs/fala-$$(date +%Y%m%d-%H%M%S).log"; \
		printf "$(GREY)Gravando em $$LOG_FILE… (Ctrl+C para parar)$(RESET)\n"; \
		log stream --predicate 'subsystem == "dev.fala.app"' --level debug --style syslog | tee "$$LOG_FILE"

clean: ## Remove artefatos de build (.build/)
	@$(SWIFT) package clean
	@printf "$(GREEN)✓ Build limpo$(RESET)\n"

release: ## Publica uma release (uso: make release BUMP=patch|minor|major)
	@bash scripts/release.sh $(BUMP)

release-dry: ## Dry-run de release (uso: make release-dry BUMP=patch)
	@bash scripts/release.sh $(BUMP) --dry-run
