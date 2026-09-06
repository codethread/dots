{
  pkgs,
  pkgsMaster ? null,
  config,
  lib,
  ...
}:

let
  agentPkgSet = if pkgsMaster == null then pkgs else pkgsMaster;
  llmAgents = agentPkgSet."llm-agents";
  cursorAgent = llmAgents.cursor-agent;
  cursorAgentCommand = pkgs.runCommand "cursor-agent-command" { } ''
    mkdir -p "$out/bin"
    ln -s ${lib.getExe cursorAgent} "$out/bin/agent"
  '';

  # Pre-compiled treesitter parsers — avoids recompilation on every nvim
  # launch (nix store GC invalidates dynamically-compiled .so paths)
  treesitter-parsers = pkgs.symlinkJoin {
    name = "nvim-treesitter-parsers";
    paths = (pkgs.vimPlugins.nvim-treesitter.withAllGrammars).passthru.dependencies;
  };

  # Package executable bindings
  atuinCmd = lib.getExe pkgs.atuin;
  carapaceCmd = lib.getExe pkgs.carapace;
  dirnameCmd = lib.getExe' pkgs.coreutils "dirname";
  findCmd = lib.getExe' pkgs.findutils "find";
  gitCmd = lib.getExe pkgs.git;
  lnCmd = lib.getExe' pkgs.coreutils "ln";
  mkdirCmd = lib.getExe' pkgs.coreutils "mkdir";
  sshCmd = lib.getExe' pkgs.openssh "ssh";
  sshKeygenCmd = lib.getExe' pkgs.openssh "ssh-keygen";
  sshKeyscanCmd = lib.getExe' pkgs.openssh "ssh-keyscan";
  grepCmd = lib.getExe' pkgs.gnugrep "grep";
  sedCmd = lib.getExe' pkgs.gnused "sed";
  nuCmd = lib.getExe pkgs.nushell;
  bootstrapPath = lib.makeBinPath [
    pkgs.git
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnugrep
    pkgs.openssh
  ];
  dottyPath = lib.makeBinPath [
    pkgs.git
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.nushell
    pkgs.bash
  ];

  atuinNushellInit =
    pkgs.runCommand "atuin-init.nu"
      {
        nativeBuildInputs = [
          pkgs.atuin
          pkgs.writableTmpDirAsHomeHook
        ];
      }
      ''
        ${atuinCmd} init nu > "$out"
        # Atuin < 18.20.1 gives Ctrl-R and Up the same name, which Nushell warns about.
        substituteInPlace "$out" \
          --replace-fail \
          $'            name: atuin\n            modifier: none\n            keycode: up' \
          $'            name: atuin_up_arrow\n            modifier: none\n            keycode: up'
      '';

  carapaceNushellInit = pkgs.runCommand "carapace-init.nu" { } ''
    ${carapaceCmd} _carapace nushell \
      | ${sedCmd} 's|"/homeless-shelter|$"($env.HOME)|g' > "$out"
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
in
{
  imports = [
    ./home-base.nix
    ./claude-code.nix
    ./pi.nix
  ];

  home.file = {
    ".local/share/nvim/nix-treesitter-parsers".source = treesitter-parsers;
    ".local/share/atuin/init.nu" = {
      source = atuinNushellInit;
      force = true;
    };
    ".local/cache/carapace/init.nu" = {
      source = carapaceNushellInit;
      force = true;
    };
    ".local/cache/direnv/init.nu" = {
      source = direnvNushellInit;
      force = true;
    };
  };

  home.activation.userBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${bootstrapPath}:$PATH"

    install_dir() {
      ${mkdirCmd} -p "$1"
    }

    clone_if_missing() {
      local url="$1"
      local dest="$2"
      local label="$3"

      if [ -d "$dest/.git" ]; then
        return 0
      fi

      install_dir "$(${dirnameCmd} "$dest")"
      echo ">>> Cloning $label into $dest"
      if ! ${gitCmd} clone --depth 1 "$url" "$dest"; then
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

      if [ ! -d "$HOME/.ssh" ] || ! ${findCmd} "$HOME/.ssh" -maxdepth 1 \( -name 'id_*' -o -name '*.pub' \) 2>/dev/null | ${grepCmd} -q .; then
        echo ">>> WARN: skipping $label clone; no SSH key found"
        return 0
      fi

      install_dir "$HOME/.ssh"
      if ! ${sshKeygenCmd} -F github.com >/dev/null 2>&1; then
        ${sshKeyscanCmd} github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
      fi

      install_dir "$(${dirnameCmd} "$dest")"
      echo ">>> Cloning $label into $dest"
      if ! GIT_SSH_COMMAND="${sshCmd} -o IgnoreUnknown=UseKeychain" ${gitCmd} clone --depth 1 "$url" "$dest"; then
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
    clone_if_missing_ssh "git@github.com:codethread/agents.git" "$HOME/dev/projects/agents" "agents"

    if [ -f "$HOME/dev/vendor/gitwatch/gitwatch.sh" ]; then
      ${lnCmd} -sfn "$HOME/dev/vendor/gitwatch/gitwatch.sh" "$HOME/.local/bin/gitwatch"
    fi

    ${lib.optionalString pkgs.stdenv.isDarwin ''
      clone_if_missing_ssh "git@github.com:codethread/alfred.git" "$HOME/sync/Alfred" "Alfred"
      clone_if_missing_ssh "git@github.com:codethread/images.git" "$HOME/sync/images" "images"
    ''}

    DOTFILES="''${DOTFILES:-$HOME/dev/dots}"
    if [ -d "$DOTFILES/.git" ]; then
      ${gitCmd} -C "$DOTFILES" config core.hooksPath .githooks
    fi
  '';

  home.activation.dottyLink = lib.hm.dag.entryAfter [ "userBootstrap" ] ''
    DOTFILES="''${DOTFILES:-$HOME/dev/dots}"
    if [ ! -d "$DOTFILES" ]; then
      echo ">>> WARN: skipping dotty link; $DOTFILES missing"
    else
      export DOTFILES
      export XDG_CONFIG_HOME="$DOTFILES/config"
      export XDG_DATA_HOME="$HOME/.local/share"
      export XDG_STATE_HOME="$HOME/.local/state"
      export XDG_CACHE_HOME="$HOME/.local/cache"
      export PATH="${dottyPath}:$PATH"

      ${nuCmd} -n -I "$DOTFILES/config/nushell/scripts" -c \
        'use ct/dotty; dotty link --no-cache | ignore'
    fi
  '';

  home.packages =
    with pkgs;
    [
      # --- Agent tools ---
      agentPkgSet.typescript
      agentPkgSet.typescript-language-server
      llmAgents.claude-code
      llmAgents.codex
      cursorAgent
      cursorAgentCommand
    ]
    ++ lib.optionals (!pkgs.stdenv.isDarwin) [
      agentPkgSet.nodejs_24
    ]
    ++ [
      # --- Languages ---
      go
      zig
      bun
      deno
      pnpm
      rustup
      python311

      # --- Shell ---
      neovim
      tmux
      smug
      atuin
      starship
      carapace
      fzf
      skim
      zellij

      # --- Utils ---
      poppler-utils
      coreutils
      fswatch
      ffmpeg
      fd
      ripgrep
      jq
      yq
      dasel
      sd
      tree
      btop
      dust
      stylua
      tree-sitter
      wakatime-cli
      prettierd
      nixfmt
      nufmt
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
      ast-grep
      vivid
    ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = false;
  };
}
