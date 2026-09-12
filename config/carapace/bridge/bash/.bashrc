# Carapace starts an isolated Bash with this rcfile for bridged completions.
# System /etc/bashrc may reset PATH (Nix-Darwin does); restore our shared contract.
source "${DOTFILES:-$HOME/dev/dots}/config/env/base.sh"

for ct_completion_file in "${BASH_SOURCE[0]%/*}"/*.bash; do
    if [ -f "$ct_completion_file" ]; then
        source "$ct_completion_file"
    fi
done
unset ct_completion_file
