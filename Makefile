.PHONY: all link build system

all: link build system

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

link:
	@printf '%s\n' '==> link'
	@nu -l -c 'dotty link --no-cache | ignore'

build:
	@printf '%s\n' '==> build'
	@cd oven && nix develop --command sh -lc "bun install && bun run verify"

system:
	@printf '%s\n' '==> system $(ARGS)'
	@nu -l -c 'use ct/nix.nu [nrs]; nrs $(ARGS)'

# Treat extra words after `make system ...` as arguments, not targets.
%:
	@:
