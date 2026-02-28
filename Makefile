XCODE   := /Applications/Xcode.app/Contents/Developer
SWIFT   := DEVELOPER_DIR=$(XCODE) swift
BUNDLE  := $(HOME)/Applications/Sussurro.app/Contents/MacOS/Sussurro
APP     := $(HOME)/Applications/Sussurro.app

# ── Cores ──────────────────────────────────────────────────────────────────────
BOLD  := \033[1m
CYAN  := \033[36m
GREEN := \033[32m
GREY  := \033[2m
RESET := \033[0m

.DEFAULT_GOAL := help
.PHONY: help test dev install kill logs clean

help: ## Mostra este menu
	@printf "\n  $(BOLD)Sussurro$(RESET)\n\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; \
	         {printf "  $(CYAN)make %-10s$(RESET) %s\n", $$1, $$2}'
	@printf "\n"

# ── Targets ────────────────────────────────────────────────────────────────────

test: ## Roda os 15 testes unitários
	@printf "$(GREY)▶ swift test$(RESET)\n"
	@$(SWIFT) test

dev: test ## test → build debug → relança o app
	@printf "$(GREY)▶ swift build$(RESET)\n"
	@$(SWIFT) build
	@cp .build/debug/Sussurro $(BUNDLE)
	@pkill Sussurro 2>/dev/null || true
	@sleep 0.3
	@open $(APP)
	@printf "$(GREEN)✓ App relançado — verifique o menu bar$(RESET)\n"

install: test ## test → build release → instala
	@printf "$(GREY)▶ swift build -c release$(RESET)\n"
	@$(SWIFT) build -c release
	@cp .build/release/Sussurro $(BUNDLE)
	@pkill Sussurro 2>/dev/null || true
	@sleep 0.3
	@open $(APP)
	@printf "$(GREEN)✓ Release instalado e rodando$(RESET)\n"

kill: ## Encerra o app
	@pkill Sussurro 2>/dev/null && printf "$(GREEN)✓ Sussurro encerrado$(RESET)\n" || printf "$(GREY)App não estava rodando$(RESET)\n"

logs: ## Mostra logs do app em tempo real (Ctrl+C para sair)
	@printf "$(GREY)Aguardando logs de Sussurro… (Ctrl+C para sair)$(RESET)\n"
	@log stream --predicate 'process == "Sussurro"' --level debug

clean: ## Remove artefatos de build (.build/)
	@$(SWIFT) package clean
	@printf "$(GREEN)✓ Build limpo$(RESET)\n"
