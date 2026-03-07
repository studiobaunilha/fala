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
.PHONY: help check lint test test-mlx hooks dev install kill logs clean release release-dry

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

test: ## Roda os testes unitários
	@printf "$(GREY)▶ swift test$(RESET)\n"
	@$(SWIFT) test

test-mlx: ## Roda smoke test do MLX via xcodebuild
	@printf "$(GREY)▶ xcodebuild test (MLX smoke)$(RESET)\n"
	@DEVELOPER_DIR=$(XCODE) bash scripts/test-mlx.sh

hooks: ## Instala git hooks (auto — no-op se já estiverem instalados)
	@[ -f "$(HOOK)" ] || bash scripts/install-hooks.sh

dev: check ## check → build debug → relança o app
	@printf "$(GREY)▶ xcodebuild (Debug)$(RESET)\n"
	@$(APPBUILD) debug --open
	@printf "$(GREEN)✓ App relançado — verifique o menu bar$(RESET)\n"

install: check ## check → build release → instala
	@printf "$(GREY)▶ xcodebuild (Release)$(RESET)\n"
	@$(APPBUILD) release --open
	@printf "$(GREEN)✓ Release instalado e rodando$(RESET)\n"

kill: ## Encerra o app
	@pkill Fala 2>/dev/null && printf "$(GREEN)✓ Fala encerrado$(RESET)\n" || printf "$(GREY)App não estava rodando$(RESET)\n"

logs: ## Mostra logs do app em tempo real (Ctrl+C para sair)
	@printf "$(GREY)Aguardando logs de Fala… (Ctrl+C para sair)$(RESET)\n"
	@log stream --predicate 'process == "Fala"' --level debug

clean: ## Remove artefatos de build (.build/)
	@$(SWIFT) package clean
	@printf "$(GREEN)✓ Build limpo$(RESET)\n"

release: ## Publica uma release (uso: make release BUMP=patch|minor|major)
	@bash scripts/release.sh $(BUMP)

release-dry: ## Dry-run de release (uso: make release-dry BUMP=patch)
	@bash scripts/release.sh $(BUMP) --dry-run
