.PHONY: all help boot plan status update link build llm-update

ROOT := $(abspath $(CURDIR))
MISE := mise -C "$(ROOT)"
NU := DOTFILES="$(ROOT)" nu -n -I "$(ROOT)/config/nushell/scripts"

all: boot

help: ## Show available commands
	@printf '%s\n\n' 'make = make boot'
	@awk 'BEGIN { FS = ":.*## " } /^[a-zA-Z0-9_-]+:.*## / { printf "  make %-12s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf '\n%s\n' 'Profiles: dev, work, personal. Override with: make plan MISE_ENV=work'
	@printf '%s\n' 'Run setup from a durable checkout; services embed its path.'

boot: ## Apply full workstation setup, skipping dirty repos
	$(MISE) bootstrap --skip-dirty

plan: ## Preview setup without applying changes
	$(MISE) bootstrap --skip-dirty --dry-run

status: ## Inspect workstation state
	$(MISE) bootstrap status

update: ## Apply setup and update declared repos/package metadata
	$(MISE) bootstrap --update

link: ## Relink dotfiles with dotty (replaces conflicts)
	$(NU) -c 'use ct/dotty; dotty link --force --no-cache "$(ROOT)/config/dotty/dotty.toml" | ignore'

build: ## Install, test, typecheck, fix, and build Oven tools/docs
	mise -C "$(ROOT)/oven" run verify

llm-update: ## Update agent CLIs through their official installers
	$(MISE) run llm:update
