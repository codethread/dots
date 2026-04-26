.PHONY: all link build system

ROOT := $(abspath $(CURDIR))
NU := DOTFILES="$(ROOT)" nu -n -I "$(ROOT)/config/nushell/scripts"

all: link build system

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

link:
	@printf '%s\n' '==> link'
	@$(NU) -c 'use ct/dotty; dotty link --force --no-cache "$(ROOT)/config/dotty/dotty.toml" | ignore'

build:
	@printf '%s\n' '==> build'
	@cd "$(ROOT)/oven" && nix develop --command sh -lc "bun install && bun run verify"

system:
	@printf '%s\n' '==> system $(ARGS)'
	@$(NU) -c 'use ct/nix.nu [nrs]; nrs $(ARGS)'

# Treat extra words after `make system ...` as arguments, not targets.
%:
	@:
