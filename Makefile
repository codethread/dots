.PHONY: all boot link build

ROOT := $(abspath $(CURDIR))
NU := DOTFILES="$(ROOT)" nu -n -I "$(ROOT)/config/nushell/scripts"

all: boot

boot:
	@printf '%s\n' '==> boot'
	@mise -C "$(ROOT)" run boot

link:
	@printf '%s\n' '==> link'
	@$(NU) -c 'use ct/dotty; dotty link --force --no-cache "$(ROOT)/config/dotty/dotty.toml" | ignore'

build:
	@printf '%s\n' '==> build'
	@mise -C "$(ROOT)/oven" run verify
