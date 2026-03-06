XCODE   := /Applications/Xcode.app/Contents/Developer
SWIFT   := DEVELOPER_DIR=$(XCODE) swift
BUNDLE  := $(HOME)/Applications/Fala.app/Contents/MacOS/Fala
APP     := $(HOME)/Applications/Fala.app
HOOK    := .git/hooks/pre-commit

# ── Cores ──────────────────────────────────────────────────────────────────────
BOLD  := \033[1m
CYAN  := \033[36m
GREEN := \033[32m
GREY  := \033[2m
RESET := \033[0m

.DEFAULT_GOAL := help
.PHONY: help check lint test hooks dev install kill logs clean release release-dry

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

hooks: ## Instala git hooks (auto — no-op se já estiverem instalados)
	@[ -f "$(HOOK)" ] || bash scripts/install-hooks.sh

dev: check ## check → build debug → relança o app
	@printf "$(GREY)▶ swift build$(RESET)\n"
	@$(SWIFT) build
	@mkdir -p $(APP)/Contents/MacOS
	@cp .build/debug/Fala $(BUNDLE)
	@mkdir -p $(APP)/Contents/Resources
	@cp Sources/Fala/Resources/AppIcon.icns $(APP)/Contents/Resources/
	@cp Sources/Fala/Resources/Info.plist $(APP)/Contents/
	@mkdir -p $(APP)/Contents/Frameworks
	@cp -R .build/debug/Sparkle.framework $(APP)/Contents/Frameworks/
	@install_name_tool -add_rpath @executable_path/../Frameworks $(BUNDLE) 2>/dev/null || true
	@codesign --force --deep --sign - $(APP)
	@pkill Fala 2>/dev/null || true
	@sleep 0.3
	@tccutil reset Accessibility dev.fala.app 2>/dev/null || true
	@open $(APP)
	@printf "$(GREEN)✓ App relançado — verifique o menu bar$(RESET)\n"

install: check ## check → build release → instala
	@printf "$(GREY)▶ swift build -c release$(RESET)\n"
	@$(SWIFT) build -c release
	@mkdir -p $(APP)/Contents/MacOS
	@cp .build/release/Fala $(BUNDLE)
	@mkdir -p $(APP)/Contents/Resources
	@cp Sources/Fala/Resources/AppIcon.icns $(APP)/Contents/Resources/
	@cp Sources/Fala/Resources/Info.plist $(APP)/Contents/
	@mkdir -p $(APP)/Contents/Frameworks
	@cp -R .build/release/Sparkle.framework $(APP)/Contents/Frameworks/
	@install_name_tool -add_rpath @executable_path/../Frameworks $(BUNDLE) 2>/dev/null || true
	@codesign --force --deep --sign - $(APP)
	@pkill Fala 2>/dev/null || true
	@sleep 0.3
	@tccutil reset Accessibility dev.fala.app 2>/dev/null || true
	@open $(APP)
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
