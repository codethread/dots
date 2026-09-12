# Carapace completions

CLIs use their generated Bash completion wrappers through Carapace's Bash bridge.
Dotty links the spec and isolated Bash rcfile into `~/.config/carapace`;
`make link` (also run by `make system`) installs them on another machine.

The registration file is saved once. Each Tab runs Bash and asks `br` for
context-aware candidates; it does not run `br completions bash` again.

Generate or refresh completions in an interactive Nushell:

```nu
setup completions br
setup completions gh
# For a CLI with a different generation command:
setup completions uv generate-shell-completion bash
```

The helper reads the CLI's help to recognize `completions bash`,
`completion bash`, or a `--shell bash` option. Extra arguments override this
detection. It saves the script and a Carapace spec under
`$DOTFILES/config/carapace`, and links them into
`$XDG_CONFIG_HOME/carapace`. It checks generation and Bash syntax before
writing, and refuses to replace unrelated config files. The shared `.bashrc`
loads all saved `.bash` wrappers.
It first loads the shared scalar environment to restore `PATH` after system
Bash startup (notably Nix-Darwin's `/etc/bashrc`).

Both the CLI and Bash must be available on `PATH`. Each generated spec selects
the Bash bridge explicitly, independently of `CARAPACE_BRIDGES` fallback order.
