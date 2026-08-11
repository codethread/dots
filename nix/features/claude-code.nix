{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ct.claude-code;
  bash = lib.getExe pkgs.bash;

  commonEnabledPlugins = {
    "claude-md-management@claude-plugins-official" = true;
    "harness@agents" = true;
    "devflow@agents" = false; # skein ftw
    "coding@agents" = true;
  };

  machineEnabledPlugins =
    if cfg.workMachine then
      {
        "admin@local-work" = true;
        "pb-prose@pb-claude" = true;
        "pb-news@pb-claude" = true;
        "pb-claude-harness-engineering@pb-claude" = true;

      }
    else
      {
        "claude-code-knowledge@claude-code-plugins" = true;
        # "bdfl@claude-code-plugins" = true;
        "dev@claude-code-plugins" = true;
        "writing@agents" = true;
      };

  claudeCodePluginsMarketplace = {
    claude-code-plugins = {
      source = {
        source = "directory";
        path = "${config.home.homeDirectory}/dev/projects/claude-code-plugins";
      };
    };
    agents = {
      source = {
        source = "directory";
        path = "${config.home.homeDirectory}/dev/projects/agents";
      };
    };
  };

  machineMarketplaces =
    claudeCodePluginsMarketplace
    // lib.optionalAttrs cfg.workMachine {
      local-work = {
        source = {
          source = "directory";
          path = "${config.home.homeDirectory}/pb/adam.hall/local-work-claude";
        };
      };
      pb-claude = {
        source = {
          source = "directory";
          path = "${config.home.homeDirectory}/pb/ai/tools/claude-plugins";
        };
      };
    };
in
{
  options.ct.claude-code = {
    enableNotify = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable cc-notify plugin and marketplace";
    };

    workMachine = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use work-only Claude Code marketplaces and plugins";
    };
  };

  config = {
    home.activation.createClaudeTmpDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p /tmp/claude && chmod 1777 /tmp/claude
    '';

    # On Linux /tmp is a tmpfs cleared at reboot; recreate via systemd-tmpfiles
    systemd.user.tmpfiles.rules = lib.optionals pkgs.stdenv.isLinux [
      "d /tmp/claude 1777 - - -"
    ];

    home.file.".claude/settings.json".text = builtins.toJSON {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
      permissions = {
        allow = [
          "Bash"
          "Edit(.claude)"
          "Read(//tmp/claude/**)"
          "Edit(//tmp/claude/**)"
          "WebFetch"
          "WebSearch"
          "Skill"
          "mcp__context7__*"
          "mcp__claude_ai_Microsoft_365__*"
          "mcp__atlassian__*"
        ];
        deny = [
          "Agent(Plan)" # garbage
          "Agent(statusline-setup)" # not needed

          "NotebookEdit" # not needed
          "WaitForMcpServers"

          "AskUserQuestion" # cheaper to just chat

          "EnterPlanMode" # moving away from plan
          "ExitPlanMode" # moving away from plan

          "CronCreate"
          "CronDelete"
          "CronList"

          "EnterWorktree"
          "ExitWorktree"

          "LSP"
          "Workflow"
          "ShareOnboardingGuide"
          "DesignSync"

          # TODO: block at hook level
          "Read(**/*.key)"
          "Read(~/*.key)"
          "Read(**/*.pem)"
          "Read(~/*.pem)"
          "Read(**/.env)"
          "Read(**/.env.*)"
          "Read(**/.env.local)"
          "Read(**/.env.production)"
          "Read(**/.git/hooks/**)"
          "Read(**/id_rsa*)"
          "Read(**/secrets/**)"
          "Read(**/.netrc)"
          "Read(~/.netrc)"
        ];
        defaultMode = "acceptEdits";
        additionalDirectories = [
          "$DOTFILES"
          "~/.local"
          "~/.claude"
          "~/dev"
          "~/pb"
        ];
      };

      enabledMcpjsonServers = [ "microsoft365" ];

      hooks = {
        PostToolUse = [
          {
            matcher = "Write";
            hooks = [
              {
                type = "command";
                command = "jq -r '.tool_input.file_path' | xargs git add -N 2>/dev/null || true";
              }
            ];
          }
        ];
      };
      statusLine = {
        type = "command";
        command = "cc-statusline";
        padding = 0;
      };
      enabledPlugins =
        commonEnabledPlugins
        // machineEnabledPlugins
        // lib.optionalAttrs cfg.enableNotify {
          "cc-notify@cc-notify-marketplace" = true;
        };
      extraKnownMarketplaces =
        machineMarketplaces
        // lib.optionalAttrs cfg.enableNotify {
          cc-notify-marketplace = {
            source = {
              source = "github";
              repo = "codethread/cc-notify";
            };
          };
        };

      # only store things we'd never override
      env = {
        TMPDIR = "/tmp/claude";
        CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR = "true";
        CLAUDE_CODE_DISABLE_TERMINAL_TITLE = "1";
        CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
        DISABLE_FEEDBACK_COMMAND = "1";
        DISABLE_ERROR_REPORTING = "1";
        DISABLE_AUTOUPDATER = "1";
        CLAUDE_CODE_NO_FLICKER = "1";
        # so we can see files
        MANPAGER = "cat";
        # avoids old shell stuff
        SHELL = "${bash}";
        # ZDOTDIR = "${config.xdg.configHome}/zsh";
        # portable user env lives in config/env/base.sh
      };

      outputStyle = "Proactive"; # "Explanatory";
      respondToBashCommands = false;
      teammateMode = "in-process"; # could make it tmux but it clobbers ui and doesn't work with nushell
      autoScrollEnabled = true; # i assume its a bug that this jumps when viewing content, but turning it to false requires constant scrolling
      disableAutoMode = "disable";
      disableWorkflows = true;
      ultracode = false;
      useAutoModeDuringPlan = false;
      autoCompactEnabled = false;
      autoMemoryEnabled = false;
      autoUpdatesChannel = "latest";
      cleanupPeriodDays = 999;
      editorMode = "vim";
      fastMode = false;
      fileCheckpointingEnabled = false;
      includeCoAuthoredBy = false;
      includeGitInstructions = false;
      preferredNotifChannel = "notifications_disabled";
      promptSuggestionEnabled = false;
      showTurnDuration = true;
      skipDangerousModePermissionPrompt = true;
      spinnerTipsEnabled = false;
      terminalProgressBarEnabled = true;
      theme = "auto";
      verbose = false;

      skillOverrides = {
        init = "off"; # doesn't work
        claude-api = "off";
        plan = "off";
        autofix-pr = "off";
        batch = "off";
        code-review = "off";
        # debug = "off";
        deep-research = "off";
        fewer-permission-prompts = "off";
        loop = "off";
      };
    };
  };
}
