# vim:fileencoding=utf-8:foldmethod=marker:foldlevel=0
use std/util "path add"

#: fns {{{

def home [p: string] {
	$nu.home-dir | path join $p
}

#: }}}
#: envs {{{

$env.DOTFILES = ($env.DOTFILES? | default (home "dev/dots"))
let is_ssh = (
	(($env.SSH_CONNECTION? | default "") != "") or
	(($env.SSH_CLIENT? | default "") != "") or
	(($env.SSH_TTY? | default "") != "")
)
let is_vscode_remote = (($env.VSCODE_IPC_HOOK_CLI? | default "") != "")

let default_editor = if $is_vscode_remote {
	"code --wait"
} else if $is_ssh {
	"nvim"
} else {
	"zed --wait"
}

$env.EDITOR = $default_editor
$env.VISUAL = $default_editor
$env.SHELL = (which nu | get 0.path)
$env.XDG_CONFIG_HOME = ($env.XDG_CONFIG_HOME? | default (home ".config"))
$env.XDG_DATA_HOME = ($env.XDG_DATA_HOME? | default (home ".local/share"))
$env.XDG_CACHE_HOME = ($env.XDG_CACHE_HOME? | default (home ".local/cache"))
$env.XDG_STATE_HOME = ($env.XDG_STATE_HOME? | default (home ".local/state"))
$env.ZDOTDIR = ($env.ZDOTDIR? | default (home ".config/zsh"))
$env.HISTFILE = ($env.HISTFILE? | default ($env.XDG_STATE_HOME | path join "bash/history"))
$env.VOLTA_HOME = ($env.VOLTA_HOME? | default (home ".volta"))
$env.CARGO_HOME = ($env.CARGO_HOME? | default ($env.XDG_DATA_HOME | path join 'cargo'))
$env.CARGO_BIN = ($env.CARGO_BIN? | default ($env.CARGO_HOME | path join 'bin'))
$env.CODEX_HOME = ($env.CODEX_HOME? | default (home ".config/codex"))
$env.MANPAGER = ($env.MANPAGER? | default "nvim +Man! -c 'lua require(\"codethread.manpager\")'")
$env.MANWIDTH = ($env.MANWIDTH? | default 80)
$env.LESSHISTFILE = ($env.LESSHISTFILE? | default "-") # no .lesshst
$env.RIPGREP_CONFIG_PATH = ([$env.XDG_CONFIG_HOME ripgrep/config] | path join)
$env.CT_VENDOR_DIR = (home "dev/vendor")


# $env.CT_LOG = '1'
$env.ENV_CONVERSIONS = {
	CT_LOG: { from_string: { |s| $s | into bool } to_string: { |v| $"($v)"} }
}
$env.CT_USER = ($env.CT_USER? | default (match ($env.USER? | default "") {
	"adam.hall" => "work",
	"adamhall" => "work",
	_ => "home",
}))

$env.KSM_WORK = $env.CT_USER == 'work'
$env.IS_WORK = $env.CT_USER == 'work'


$env.CT_NOTES = (match $env.CT_USER {
	"work" => (home 'gdrive/perks'),
	# macOS iCloud path; Linux fallback to ~/notes
	_ => (if (sys host).name == "Darwin" {
		home 'Library/Mobile Documents/com~apple~CloudDocs/Documents/Notes'
	} else {
		home 'notes'
	}),
})

$env.WAKATIME_HOME = ($env.WAKATIME_HOME? | default (home ".config/wakatime"))
$env.STARSHIP_CACHE = ($env.STARSHIP_CACHE? | default ($env.XDG_CACHE_HOME | path join "starship"))

if (sys host).name == "Darwin" {
	path add -a "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
	path add -a "/Applications/Cursor.app/Contents/Resources/app/bin"
	$env.CT_BACKGROUNDS_DIR = ($env.CT_BACKGROUNDS_DIR? | default (home "sync/images/backgrounds"))
}

path add "/opt/podman/bin"

path add -a "~/.local/share/nvim/mason/bin"

#: }}}
#: nix {{{
let _nix_per_user = $"/etc/profiles/per-user/($env.USER)/bin"

if ("/etc/NIXOS" | path exists) or ("/run/current-system/sw/bin" | path exists) {
	path add (home ".nix-profile/bin")
	path add "/nix/var/nix/profiles/default/bin"
	path add "/run/current-system/sw/bin"
	path add $_nix_per_user
}

if ("/etc/NIXOS" | path exists) {
	$env.IS_NIXOS = true
	# setuid wrappers (sudo, etc.) — must come before /run/current-system/sw/bin
	path add "/run/wrappers/bin"
	path add ($env.XDG_STATE_HOME | path join "nix/profile/bin")
	$env.DOCKER_HOST = $"unix:///run/user/(id -u)/podman/podman.sock"
	$env.PLAYWRIGHT_MCP_EXECUTABLE_PATH = $"($_nix_per_user)/chromium"
} else {
	$env.IS_NIXOS = false
	$env.PLAYWRIGHT_MCP_EXECUTABLE_PATH = "/Applications/Chromium.app/Contents/MacOS/Chromium"
}

# stable symlink to nix store path; avoids hash-heavy store path in pi system prompts (~130 tokens/session)
$env.PI_PACKAGE_DIR = ("~/.pi/pi-source")
$env.PI_OFFLINE = 1

#: }}}
#: pandora {{{

$env.PDX_DATA_DIR = ($env.PDX_DATA_DIR? | default (home ".pdx"))
$env.PITHOS_DB = ([$env.PDX_DATA_DIR pithos.sqlite] | path join)
$env.PDX_USER_DATA_DIR = (match $env.CT_USER {
  "work" => (home work/me/workfiles/pdx)
  _ => ([$env.XDG_CONFIG_HOME pdx] | path join)
})

#: }}}
#: homebrew {{{

if (sys host).name == "Darwin" {
	path add -a "/opt/homebrew/sbin"
	path add -a "/opt/homebrew/bin"

	$env.HOMEBREW_BUNDLE_FILE = ("~/.local/data/Brewfile.conf" | path expand)

	$env.HOMEBREW_CELLAR = "/opt/homebrew/Cellar"
	$env.HOMEBREW_PREFIX = "/opt/homebrew"
	$env.HOMEBREW_REPOSITORY = "/opt/homebrew"
	# not sure if these matter?
	# $env.INFOPATH = "/opt/homebrew/share/info:"
	# $env.MANPATH = ([$env.MANPATH "/opt/homebrew/share/man:"] | str join)
}

#: }}}
#: emacs {{{

$env.LSP_USE_PLISTS = "true"
path add "~/.emacs.d/bin"

#: }}}
#: fzf {{{

$env.FZF_ALT_C_COMMAND = "fd --hidden --type d --exclude '{Library,Movies,Music,Applications,Pictures,Unity,VirtualBox VMs,WebstormProjects,Tools,node_modules,.git}' . ~"
$env.FZF_CTRL_T_COMMAND = "fd --type f --hidden --exclude '{.git}'"
$env.FZF_DEFAULT_COMMAND = "fd --type f --hidden --exclude '{.git}'"
# rose pine moon
$env.FZF_DEFAULT_OPTS = "--color=fg+:#e0def4,bg+:#393552,hl+:#ea9a97,border:#44415a,header:#3e8fb0,gutter:#232136,spinner:#f6c177,info:#9ccfd8,pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa"

#: }}}
#: go {{{

path add "~/go/bin"
$env.GOBIN = (home "go/bin")
$env.GOPATH = (home "go")

#: }}}
#: javascript / node / react-native {{{

if (sys host).name == "Darwin" {
	# android simulator
	$env.ANDROID_HOME = ("~/Library/Android/sdk" | path expand)
	path add ($env.ANDROID_HOME | path join "emulator")
	path add ($env.ANDROID_HOME | path join "platform-tools")

	# ruby for gem install on m1 mac ios pods
	path add "/opt/homebrew/opt/ruby@3.1/bin"
	path add "/opt/homebrew/lib/ruby/gems/3.1.0/bin"
}

path add ($env.VOLTA_HOME | path join "bin")
$env.VOLTA_FEATURE_PNPM = "1"
# $env.HUSKY = "0" # don"t hold my hand

path add "~/.bun/bin"

#: }}}
#: rust {{{

$env.RUSTUP_HOME = ($env.RUSTUP_HOME? | default ($env.XDG_DATA_HOME | path join 'rustup'))
path add $env.CARGO_BIN

# $env.RUSTFLAGS = (match $env.CT_USER {
#   "work" => "-C link-arg=-fuse-ld=/opt/homebrew/opt/llvm/bin/ld64.lld"
#   _ => ""
# })

#: }}}
#: lua {{{

path add "~/.luarocks/bin"

#: }}}
#: java {{{

if (sys host).name == "Darwin" {
	$env.JAVA_HOME = "/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
}

#: }}}
#: python {{{

# Python environment variables
$env.PYTHONDONTWRITEBYTECODE = "1"  # Don't create .pyc files
$env.PIP_REQUIRE_VIRTUALENV = "false"  # Allow pip outside virtualenv (set to "true" to be stricter)

#: }}}
#: claude {{{

$env.CT_PLUGINS_DIR = echo "~/dev/learn/claude-plugins/plugins" | path expand
$env.PI_CODING_AGENT_DIR = ($env.PI_CODING_AGENT_DIR? | default (home ".pi/agent"))
$env.ENABLE_CLAUDEAI_MCP_SERVERS = "0"

#: }}}
#: kitty {{{

# macOS kitty.app bundle ships its own binary; on Linux, kitty is installed system-wide
if (sys host).name == "Darwin" {
	let kitty = "/Applications/kitty.app"
	if ($kitty | path exists) {
		path add ([$kitty, "Contents/MacOS"] | path join)
		let kitty_man = "/Applications/kitty.app/Contents/Resources/man:"
		$env.MANPATH = ([($env | get --optional MANPATH) $kitty_man] | str join)
	}
}

#: }}}
#: nushell {{{

# not sure if needed
$env.CARAPACE_BRIDGES = 'fish,bash,inshellisense' # optional

# Directories to search for scripts when calling source or use
$env.NU_LIB_DIRS = [
    ($nu.default-config-dir | path join "scripts")
    ($env.DOTFILES | path join "config/nushell/scripts")
    ("~/dev/vendor/nu_scripts/sourced" | path expand)
]

# Directories to search for plugin binaries when calling register
$env.NU_PLUGIN_DIRS = [$env.CARGO_BIN]

path add "~/.linkerd2/bin"

#: }}}
# keep this at the end
path add -a "/usr/local/bin"
path add "~/.local/bin"
path add ($env.PDX_DATA_DIR | path join "bin")
$env.path = ($env.path | uniq)
