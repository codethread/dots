#!/usr/bin/env bash

# if the current tab has one window, split, else toggle zoom
if [[ $(kitten @ ls --match-tab recent:0 | jq '.[0].tabs.[0].groups | length') == 1 ]]; then
  kitten @ launch --location=vsplit --cwd=current 
else 
  kitten @ action toggle_layout stack
fi
