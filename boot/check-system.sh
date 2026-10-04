#!/bin/bash
# :module: Check the macOS sudo prerequisites before bootstrap writes managed files.
set -euo pipefail

case "${1:-}" in
  -h|--help) echo 'Usage: boot/check-system.sh (also run by mise bootstrap)'; exit 0 ;;
  '') ;;
  *) echo "Unexpected argument: $1" >&2; exit 2 ;;
esac

[ "$(uname -s)" = Darwin ] || { echo 'Workstation bootstrap requires macOS' >&2; exit 1; }
[ -f /etc/pam.d/sudo_local.template ] || { echo 'Touch ID setup requires macOS 14 or newer' >&2; exit 1; }
if [ -L /etc/pam.d/sudo_local ]; then
  echo 'sudo_local is a symlink; retire its previous owner before applying' >&2
  exit 1
fi
/usr/bin/grep -Eq '^auth[[:space:]]+include[[:space:]]+sudo_local([[:space:]]|$)' /etc/pam.d/sudo || {
  echo 'Stock sudo_local include missing from /etc/pam.d/sudo; inspect the PAM stack before applying' >&2
  exit 1
}
[ -f /opt/homebrew/lib/pam/pam_reattach.so ] || { echo 'Missing pam-reattach; apply bootstrap packages first' >&2; exit 1; }
