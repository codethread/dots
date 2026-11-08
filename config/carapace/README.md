# Carapace completions

CLIs use their generated Bash completion wrappers through Carapace's Bash bridge. Native mise dotfile deployment is the sole installer of the generated spec, wrapper, and isolated Bash rcfile in `~/.config/carapace`.

The registration file is saved once. Each Tab runs Bash and asks the target CLI for context-aware candidates; it does not regenerate its completion wrapper.

Generate or refresh completions in an interactive Nushell:

```nu
setup completions gh
# For a CLI with a different generation command:
setup completions uv generate-shell-completion bash
```

The helper reads the CLI's help to recognize `completions bash`, `completion bash`, or a `--shell bash` option. Extra arguments override this detection. It checks generation and Bash syntax, then saves the script and a Carapace spec under `$DOTFILES/config/carapace`. The shared `.bashrc` loads all saved `.bash` wrappers and inherits the caller's environment, including its `PATH`; the bridge is not a login shell and does not source `config/env/base.sh`.

Because the `config` dotfile group uses the Git manifest, stage newly generated files before deployment:

```sh
git add config/carapace/bridge/bash/<binary>.bash config/carapace/specs/<binary>.yaml
mise dot apply --dry-run
mise run link
```

Run the apply from the durable checkout after reviewing the dry run. Generation itself does not modify the live home or resolve destination conflicts; mise owns those checks and links.

Both the CLI and Bash must be available on `PATH`. Each generated spec selects the Bash bridge explicitly, independently of `CARAPACE_BRIDGES` fallback order.
