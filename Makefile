.PHONY: all boot link build system
# Finish the system switch before mise prepares shells and loads services.
.NOTPARALLEL: all

ROOT := $(abspath $(CURDIR))
NU := DOTFILES="$(ROOT)" nu -n -I "$(ROOT)/config/nushell/scripts"

all: system boot

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

boot:
	@printf '%s\n' '==> boot'
	@mise -C "$(ROOT)" run boot

link:
	@printf '%s\n' '==> link'
	@$(NU) -c 'use ct/dotty; dotty link --force --no-cache "$(ROOT)/config/dotty/dotty.toml" | ignore'

build:
	@printf '%s\n' '==> build'
	@mise -C "$(ROOT)/oven" run verify

system:
	@printf '%s\n' '==> system $(ARGS)'
	@$(NU) -c 'use ct/nix.nu [nrs]; nrs $(ARGS)'

# Treat extra words after `make system ...` as arguments, not targets.
%:
	@:
