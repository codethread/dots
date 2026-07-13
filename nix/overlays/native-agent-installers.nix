final: prev: {
  nativeAgentInstallClaude = final.writeShellApplication {
    name = "native-agent-install-claude";
    runtimeInputs = [
      final.coreutils
      final.curl
      final.bash
      final.perl
    ];
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
