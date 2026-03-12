#!/usr/bin/env bash
set -euo pipefail

current_layout=$(kitten @ ls --match-tab recent:0 | jq -r '.[0].tabs.[0].layout')

case "$current_layout" in
  "fat")
    kitten @ goto-layout --match "state:focused" tall
    ;;
  "tall")
    kitten @ goto-layout --match "state:focused" fat
    ;;
esac
