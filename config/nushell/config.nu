use ct/boot
use ct/themes.nu themes
use ct/config [keybindings menus hooks]
use ct/core *
use ct/tmux
use ct/dotty
use ct/cursor.nu *
use ct/macos.nu *
use ct/git *
use ct/git/worktree *
use ct/homebrew.nu *
use ct/editor.nu *
use ct/terminal.nu *
use ct/onepassword.nu *
use ct/system.nu *
use ct/nix.nu *
use ct/nixos.nu *
use ct/search.nu *
use ct/purge.nu

# $ config nu --doc | nu-highlight | less -R
$env.config.table.mode = "compact" # default 'rounded', also 'markdown' handy for scripts
# $env.config.table.mode = "light" # default 'rounded', also 'markdown' handy for scripts
$env.config.table.index_mode = "auto"
$env.config.table.show_empty = false # show 'empty list' and 'empty record' placeholders for command output
$env.config.cursor_shape = $env.config.cursor_shape | merge {
	# block, underscore, line, blink_block, blink_underscore, blink_line (line is the default)
	emacs: "blink_block"
	vi_insert: "blink_line"
	vi_normal: "blink_block"
}
# NOTE: may need to check how this behaves for scripts and nush
$env.config.display_errors.exit_code = false # this shows a nushell error, which is annoying in repl
$env.config.display_errors.termination_signal = true
$env.config.use_ansi_coloring = "auto"
$env.config.use_kitty_protocol = true # who knows
$env.config.shell_integration = $env.config.shell_integration | merge {
	osc2 : true
	osc7 : true
	osc8 : true
	# osc9_9 : true # sends the path, but also causes notifications
	osc133 : true
	osc633 : true
	reset_application_mode : true
}
$env.config.completions.algorithm = "fuzzy"
$env.config.show_banner = false
$env.config.color_config = $themes.dark
$env.config.edit_mode = 'emacs' # emacs, vi
$env.config.render_right_prompt_on_last_line = false # true or false to enable or disable right prompt to be rendered on last line of the prompt.
$env.config.highlight_resolved_externals = true

$env.config.keybindings ++= $keybindings
$env.config.menus ++= $menus
$env.config.hooks = (hooks)

$env.STARSHIP_SHELL = "nu"
$env.PROMPT_COMMAND = {||
	starship prompt --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)'
}
$env.PROMPT_COMMAND_RIGHT = {||
	starship prompt --right
}
$env.PROMPT_INDICATOR = ""
$env.PROMPT_INDICATOR_VI_INSERT = ": "
$env.PROMPT_INDICATOR_VI_NORMAL = "〉"
$env.PROMPT_MULTILINE_INDICATOR = "::: "

const workp = ("~/.work.nu" | path expand)
source (if ($workp | path exists) { $workp } else { null })

const privates = ("~/.privates.nu" | path expand)
source (if ($privates | path exists) { $privates } else { null })
