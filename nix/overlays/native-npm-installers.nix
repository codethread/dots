final: prev:
let
  npm = "${final.nodejs_24}/bin/npm";
in {
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

  nativeNpmInstallOpenspec = final.writeShellApplication {
    name = "native-npm-install-openspec";
    runtimeInputs = [ final.coreutils final.nodejs_24 ];
    text = ''
      set -euo pipefail

      export HOME="''${HOME:?HOME is required}"
      export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-$HOME/.local}"

      if [ "''${1:-}" = "--if-missing" ] && ${npm} ls -g --depth=0 @fission-ai/openspec >/dev/null 2>&1; then
        exit 0
      fi

      exec ${npm} install -g @fission-ai/openspec@latest
    '';
  };

  nativeNpmOpenspec = final.writeShellApplication {
    name = "openspec";
    runtimeInputs = [ final.coreutils final.nodejs_24 ];
    text = ''
      set -euo pipefail

      export HOME="''${HOME:?HOME is required}"
      export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-$HOME/.local}"

      if [ ! -x "$HOME/.local/bin/openspec" ]; then
        ${final.nativeNpmInstallOpenspec}/bin/native-npm-install-openspec
      fi

      exec "$HOME/.local/bin/openspec" "$@"
    '';
  };
}
