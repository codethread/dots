final: prev:
let
  npm = "${final.nodejs_24}/bin/npm";
in {
  nativeAgentRefreshPiSource = final.writeShellApplication {
    name = "native-agent-refresh-pi-source";
    runtimeInputs = [ final.coreutils final.nodejs_24 ];
    text = ''
      set -euo pipefail

      export HOME="''${HOME:?HOME is required}"
      export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-$HOME/.local}"

      package_dir="$(${npm} root -g)/@mariozechner/pi-coding-agent"
      mkdir -p "$HOME/.pi"

      if [ ! -d "$package_dir" ]; then
        echo "pi package not found at $package_dir" >&2
        exit 1
      fi

      ln -sfn "$package_dir" "$HOME/.pi/pi-source"
    '';
  };

  nativeAgentInstallPi = final.writeShellApplication {
    name = "native-agent-install-pi";
    runtimeInputs = [ final.coreutils final.nodejs_24 ];
    text = ''
      set -euo pipefail

      export HOME="''${HOME:?HOME is required}"
      export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-$HOME/.local}"

      if [ "''${1:-}" = "--if-missing" ] && ${npm} ls -g --depth=0 @mariozechner/pi-coding-agent >/dev/null 2>&1; then
        exec ${final.nativeAgentRefreshPiSource}/bin/native-agent-refresh-pi-source
      fi

      ${npm} install -g @mariozechner/pi-coding-agent@latest
      exec ${final.nativeAgentRefreshPiSource}/bin/native-agent-refresh-pi-source
    '';
  };

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

  nativeAgentInstallClaude = final.writeShellApplication {
    name = "native-agent-install-claude";
    runtimeInputs = [ final.coreutils final.curl final.bash ];
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
