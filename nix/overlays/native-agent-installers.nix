final: prev:
let
  npm = "${final.nodejs_24}/bin/npm";
in {
  nativeAgentInstallCodex = final.writeShellApplication {
    name = "native-agent-install-codex";
    runtimeInputs = [ final.coreutils final.nodejs_24 ];
    text = ''
      set -euo pipefail

      export HOME="''${HOME:?HOME is required}"
      export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-$HOME/.local}"

      if [ "''${1:-}" = "--if-missing" ] && ${npm} ls -g --depth=0 @openai/codex >/dev/null 2>&1; then
        exit 0
      fi

      exec ${npm} install -g @openai/codex@latest
    '';
  };

  nativeAgentInstallBitwarden = final.writeShellApplication {
    name = "native-agent-install-bitwarden";
    runtimeInputs = [ final.coreutils final.nodejs_24 ];
    text = ''
      set -euo pipefail

      export HOME="''${HOME:?HOME is required}"
      export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-$HOME/.local}"

      if [ "''${1:-}" = "--if-missing" ] && ${npm} ls -g --depth=0 @bitwarden/cli >/dev/null 2>&1; then
        exit 0
      fi

      exec ${npm} install -g @bitwarden/cli@latest
    '';
  };

  nativeAgentInstallClaude = final.writeShellApplication {
    name = "native-agent-install-claude";
    runtimeInputs = [ final.coreutils final.curl final.bash final.perl ];
    text = ''
      set -euo pipefail

      export HOME="''${HOME:?HOME is required}"

      if [ -x "$HOME/.local/bin/claude" ]; then
        exec "$HOME/.local/bin/claude" update
      fi

      installer="$(mktemp)"
      trap 'rm -f "$installer"' EXIT

      curl -fsSL https://claude.ai/install.sh -o "$installer"
      bash "$installer"
    '';
  };
}
