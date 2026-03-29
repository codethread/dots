{ config, lib, ... }:

let
  cfg = config.ct.claude-code;
in {
  options.ct.claude-code = {
    enableNotify = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable cc-notify plugin and marketplace";
    };
  };

  config = {
    home.file.".claude/settings.json".text = builtins.toJSON {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
      permissions = {
        allow = [
          "Bash"
          "Edit(.claude)"
          "WebFetch"
          "WebSearch"
          "Skill"
          "mcp__context7__resolve-library-id"
          "mcp__context7__query-docs"
        ];
        deny = [
          "Agent(Plan)" # garbage
          "Agent(statusline-setup)" # not needed
          "NotebookEdit" # not needed
		  "AskUserQuestion" # cheaper to just chat
		  "EnterPlanMode" # moving away from plan
		  "ExitPlanMode" # moving away from plan

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
          "Bash(git commit --amend*)"
          "Bash(git rebase -i*)"
        ];
        defaultMode = "acceptEdits";
        additionalDirectories = [
          "~/PersonalConfigs"
          "~/.local"
          "~/.claude"
          "~/dev"
          "~/work"
          "~/workfiles"
        ];
      };
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
        SessionEnd = [
          {
            hooks = [
              {
                type = "command";
                command = "cc-hook--context-injector session-end";
              }
            ];
          }
        ];
        SessionStart = [
          {
            hooks = [
              {
                type = "command";
                command = "cc-hook--context-injector session-start";
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
      enabledPlugins = {
        "frontend-design@claude-plugins-official" = true;
        "typescript-lsp@claude-plugins-official" = true;
        "claude-md-management@claude-plugins-official" = true;
        "claude-code-knowledge@codethread-plugins" = true;
      } // lib.optionalAttrs cfg.enableNotify {
        "cc-notify@cc-notify-marketplace" = true;
      };
      extraKnownMarketplaces = {
        claude-code-plugins = {
          source = {
            source = "directory";
            path = "${config.home.homeDirectory}/dev/projects/claude-code-plugins";
          };
        };
      } // lib.optionalAttrs cfg.enableNotify {
        cc-notify-marketplace = {
          source = {
            source = "github";
            repo = "codethread/cc-notify";
          };
        };
      };

      env = {
        CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR = "true";
        CLAUDE_CODE_DISABLE_TERMINAL_TITLE = "1";
        CLAUDE_CODE_DISABLE_AUTO_MEMORY = "1";
        CLAUDE_CODE_DISABLE_CRON = "1";
        DISABLE_FEEDBACK_COMMAND = "1";
        DISABLE_ERROR_REPORTING = "1";
        ENABLE_TOOL_SEARCH = "0";
        DISABLE_TELEMETRY = "1";
        DISABLE_AUTOUPDATER = "0";
        ENABLE_CLAUDEAI_MCP_SERVERS = "0";
        MANPAGER = "cat";
        ZDOTDIR = "~/.config/zsh-claude";
        "__CC_CUSTOM_ENVS_" = "manpager so we can see files, ZDOTDIR avoids old shell stuff";
      };

	  spinnerTipsEnabled = false;
      autoMemoryEnabled = false;
      autoUpdatesChannel = "latest";
      cleanupPeriodDays = 999;
      fastMode = false;
      includeCoAuthoredBy = false;
      includeGitInstructions = false;
      promptSuggestionEnabled = false;
      skipDangerousModePermissionPrompt = true;
    };
  };
}
