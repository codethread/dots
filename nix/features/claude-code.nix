{ config, lib, pkgs, ... }:

let
  cfg = config.ct.claude-code;
  zsh = lib.getExe pkgs.zsh;

  commonEnabledPlugins = {
    "frontend-design@claude-plugins-official" = true;
    "claude-md-management@claude-plugins-official" = true;

	"harness@agents" = true;
	"devflow@agents" = true;
	"coding@agents" = true;
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

  machineEnabledPlugins = if cfg.workMachine then {
    "pb-go@pb-claude" = true;
    "pb-aws@pb-claude" = true;
    "pb-prose@pb-claude" = true;
    "pb-claude-harness-engineering@pb-claude" = true;

  } else {
    "claude-code-knowledge@claude-code-plugins" = true;
    # "bdfl@claude-code-plugins" = true;
    "dev@claude-code-plugins" = true;
	"writing@agents" = true;
  };

  machineMarketplaces = claudeCodePluginsMarketplace // lib.optionalAttrs cfg.workMachine {
    ai-tools-marketplace = {
      source = {
        source = "git";
        url = "ssh://git@git.perkbox.io/adam.hall/ai-tools.git";
      };
      autoUpdate = true;
    };
    pb-claude = {
      source = {
        source = "directory";
        path = "${config.home.homeDirectory}/work/ai/tools/claude-plugins--pb-adhoc-agents";
      };
    };
  };
in {
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
          "Read(//tmp/claude/**)"
          "Write(//tmp/claude/**)"
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
		  "ScheduleWakeup"
		  "Workflow"

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

		  # TODO: can probably be brave here
          "Bash(git reset --hard*)"
          "Bash(git clean -f*)"
          "Bash(git branch -D*)"
          "Bash(git config*)"
          # "Bash(git commit --amend*)"
          "Bash(git rebase -i*)"
        ];
        defaultMode = "acceptEdits";
        additionalDirectories = [
          "$DOTFILES"
          "~/.local"
          "~/.claude"
          "~/dev"
          "~/work"
          "~/work/me/workfiles"
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
        PreToolUse = [
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "cc-hook--npm-redirect";
              }
            ];
          }
        ];
        # SessionEnd = [
        #   {
        #     hooks = [
        #       {
        #         type = "command";
        #         command = "cc-hook--context-injector session-end";
        #       }
        #     ];
        #   }
        # ];
        # SessionStart = [
        #   {
        #     hooks = [
        #       {
        #         type = "command";
        #         command = "cc-hook--context-injector session-start";
        #       }
        #     ];
        #   }
        # ];
      };
      statusLine = {
        type = "command";
        command = "cc-statusline";
        padding = 0;
      };
      enabledPlugins = commonEnabledPlugins // machineEnabledPlugins // lib.optionalAttrs cfg.enableNotify {
        "cc-notify@cc-notify-marketplace" = true;
      };
      extraKnownMarketplaces = machineMarketplaces // lib.optionalAttrs cfg.enableNotify {
        cc-notify-marketplace = {
          source = {
            source = "github";
            repo = "codethread/cc-notify";
          };
        };
      };

      env = {
        TMPDIR = "/tmp/claude";
        CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR = "true";
        CLAUDE_CODE_DISABLE_TERMINAL_TITLE = "1";
        CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
        CLAUDE_CODE_DISABLE_CRON = "1";
        CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING = "1";
        CLAUDE_CODE_DISABLE_1M_CONTEXT = "1";
        DISABLE_FEEDBACK_COMMAND = "1";
        DISABLE_ERROR_REPORTING = "1";
        ENABLE_TOOL_SEARCH = "0";
        DISABLE_TELEMETRY = "0";
        DISABLE_AUTOUPDATER = "0";
        CLAUDE_CODE_NO_FLICKER = "1";
        # so we can see files
        MANPAGER = "cat";
        # avoids old shell stuff
        SHELL = "${zsh}";
        ZDOTDIR = "${config.xdg.configHome}/zsh";
      };

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
		autofix-pr =  "off";
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
