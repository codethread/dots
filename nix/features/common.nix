{ pkgs, pkgsMaster ? null, config, lib, ... }:

let
  agentPkgSet = if pkgsMaster == null then pkgs else pkgsMaster;
  llmAgents = agentPkgSet."llm-agents";

  # Pre-compiled treesitter parsers — avoids recompilation on every nvim
  # launch (nix store GC invalidates dynamically-compiled .so paths)
  treesitter-parsers = pkgs.symlinkJoin {
    name = "nvim-treesitter-parsers";
    paths = (pkgs.vimPlugins.nvim-treesitter.withAllGrammars).passthru.dependencies;
  };

  atuinNushellInit = pkgs.runCommand "atuin-init.nu"
    {
      nativeBuildInputs = [ pkgs.atuin pkgs.writableTmpDirAsHomeHook ];
    }
    ''
      ${pkgs.atuin}/bin/atuin init nu > "$out"
    '';

  carapaceNushellInit = pkgs.runCommand "carapace-init.nu" { } ''
    ${pkgs.carapace}/bin/carapace _carapace nushell \
      | ${pkgs.gnused}/bin/sed 's|"/homeless-shelter|$"($env.HOME)|g' > "$out"
  '';

  direnvNushellInit = pkgs.writeText "direnv-init.nu" ''
    $env.config.hooks.env_change.PWD = $env.config.hooks.env_change.PWD? | default []
    $env.config.hooks.env_change.PWD ++= [{||
      if (which direnv | is-empty) { return }
      direnv export json | from json | default {} | load-env
      if ($env.PATH | describe) == 'string' {
        $env.PATH = $env.PATH | split row (char esep)
      }
    }]
  '';
in {
  imports = [ ./claude-code.nix ];

  home.stateVersion = "24.11";

  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.local";
  };
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.local
  '';

  home.file.".local/share/nvim/nix-treesitter-parsers".source = treesitter-parsers;
  # Stable short path so PI_PACKAGE_DIR avoids the hash-heavy nix store path in system prompts
  home.file.".pi/pi-source".source = "${llmAgents.pi}/lib/node_modules/@mariozechner/pi-coding-agent";
  home.file.".local/share/atuin/init.nu" = {
    source = atuinNushellInit;
    force = true;
  };
  home.file.".local/cache/carapace/init.nu" = {
    source = carapaceNushellInit;
    force = true;
  };
  home.file.".local/cache/direnv/init.nu" = {
    source = direnvNushellInit;
    force = true;
  };

  home.activation.userBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install_dir() {
      ${pkgs.coreutils}/bin/mkdir -p "$1"
    }

    clone_if_missing() {
      local url="$1"
      local dest="$2"
      local label="$3"

      if [ -d "$dest/.git" ]; then
        return 0
      fi

      install_dir "$(${pkgs.coreutils}/bin/dirname "$dest")"
      echo ">>> Cloning $label into $dest"
      if ! ${pkgs.git}/bin/git clone --depth 1 "$url" "$dest"; then
        echo ">>> WARN: failed to clone $label; continuing"
      fi
    }

    clone_if_missing_ssh() {
      local url="$1"
      local dest="$2"
      local label="$3"

      if [ -d "$dest/.git" ]; then
        return 0
      fi

      if [ ! -d "$HOME/.ssh" ] || ! ${pkgs.findutils}/bin/find "$HOME/.ssh" -maxdepth 1 \( -name 'id_*' -o -name '*.pub' \) 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q .; then
        echo ">>> WARN: skipping $label clone; no SSH key found"
        return 0
      fi

      install_dir "$HOME/.ssh"
      if ! ${pkgs.openssh}/bin/ssh-keygen -F github.com >/dev/null 2>&1; then
        ${pkgs.openssh}/bin/ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
      fi

      install_dir "$(${pkgs.coreutils}/bin/dirname "$dest")"
      echo ">>> Cloning $label into $dest"
      if ! ${pkgs.git}/bin/git clone --depth 1 "$url" "$dest"; then
        echo ">>> WARN: failed to clone $label; continuing"
      fi
    }

    install_dir "$HOME/dev/vendor"
    install_dir "$HOME/dev/learn"
    install_dir "$HOME/dev/projects"
    install_dir "$HOME/.local/cache/docs"
    install_dir "$HOME/.local/bin"

    clone_if_missing "https://github.com/nushell/nu_scripts.git" "$HOME/dev/vendor/nu_scripts" "nu_scripts"
    clone_if_missing "https://github.com/gitwatch/gitwatch.git" "$HOME/dev/vendor/gitwatch" "gitwatch"

    if [ -f "$HOME/dev/vendor/gitwatch/gitwatch.sh" ]; then
      ${pkgs.coreutils}/bin/ln -sfn "$HOME/dev/vendor/gitwatch/gitwatch.sh" "$HOME/.local/bin/gitwatch"
    fi

    ${lib.optionalString pkgs.stdenv.isDarwin ''
      clone_if_missing_ssh "git@github.com:codethread/alfred.git" "$HOME/sync/Alfred" "Alfred"
    ''}

    if [ -d "$HOME/PersonalConfigs/.git" ]; then
      ${pkgs.git}/bin/git -C "$HOME/PersonalConfigs" config core.hooksPath .githooks
    fi
  '';

  home.activation.dottyLink = lib.hm.dag.entryAfter [ "userBootstrap" ] ''
    DOTFILES="$HOME/PersonalConfigs"
    if [ ! -d "$DOTFILES" ]; then
      echo ">>> WARN: skipping dotty link; $DOTFILES missing"
      return 0
    fi

    export DOTFILES
    export XDG_CONFIG_HOME="$DOTFILES/config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.local/cache"
    export PATH="${lib.makeBinPath [
      pkgs.git
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.nushell
      pkgs.bash
    ]}:$PATH"

    ${pkgs.nushell}/bin/nu -n -I "$DOTFILES/config/nushell/scripts" -c \
      'use ct/dotty; dotty link --no-cache | ignore'
  '';

  home.packages = with pkgs; [
    # --- Agent tools ---
    agentPkgSet.nodejs_24
    playwright-cli
    agentPkgSet.typescript
    agentPkgSet.typescript-language-server
    llmAgents.codex
    llmAgents.opencode
    llmAgents.claude-code
    llmAgents.pi

    # --- Languages ---
    go
    zig
    bun
    deno

    # --- Shell ---
    neovim
    tmux
    smug
    atuin
    starship
    carapace
    fzf

    # --- Utils ---
    poppler-utils
    bat
    fd
    ripgrep
    jq
    yq
    dasel
    sd
    tree
    dust
    stylua
    wakatime-cli
    prettierd
    just
    uv
    fx
    tokei
    grc
    todoist-cli
    gh
    git-lfs
    lazygit
	lazydocker
    difftastic
    yt-dlp
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = false;
  };
}
