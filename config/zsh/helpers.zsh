# Interactive helpers ported from config/nushell/scripts/ct/.

alias gl='git log --oneline --no-merges'
alias gcp='git cherry-pick'

_dots_git_main() {
  local ref
  ref=$(git symbolic-ref --short refs/remotes/origin/HEAD) || return
  print -r -- "${ref#origin/}"
}

gll() {
  local main
  main=$(_dots_git_main) || return
  git log --oneline "$main..HEAD" --no-merges "$@"
}

gcm() {
  local msg="${(j: :)@}"
  print -r -- "$msg"
  git commit --message "$msg"
}

# Like Nushell: stage this directory and skip commit hooks.
gwip() {
  if (($# > 1)); then
    print -u2 'usage: gwip ["message"]'
    return 2
  fi
  git add . || return
  git commit -nm "${1-wip}"
}

gmm() {
  local main
  main=$(_dots_git_main) || return
  git fetch origin || return
  git rebase "origin/$main"
}

gnew() {
  if (($# != 1)) || ((${#1} > 52)); then
    print -u2 'usage: gnew <branch-name> (at most 52 characters)'
    return 2
  fi
  git check-ref-format --branch "$1" >/dev/null || return
  local main current
  main=$(_dots_git_main) || return
  current=$(git symbolic-ref --short HEAD) || return
  if [[ $current == $main ]]; then
    git pull || return
  else
    git fetch origin "$main:$main" || return
  fi
  git checkout --no-track -b "$1" "$main"
}

# Rebase only our side of the fork, not a count of both sides' commits.
grb() {
  local main base
  main=$(_dots_git_main) || return
  base=$(git merge-base "$main" HEAD) || return
  git rebase -i "$base"
}

gundo() {
  git reset --soft HEAD~1 || return
  git restore --staged .
}

# Yazi's cwd file allows changing the parent shell's directory on exit.
yy() {
  local tmp cwd
  tmp=$(mktemp -t yazi-cwd.XXXXXX) || return
  {
    command yazi "$@" --cwd-file "$tmp" || return
    cwd=$(<"$tmp")
    if [[ -n $cwd && $cwd != $PWD && -d $cwd ]]; then
      builtin cd -- "$cwd"
    fi
  } always {
    rm -f -- "$tmp"
  }
}

port-kill() {
  local port pids
  for port in "$@"; do
    if [[ $port != <1-65535> ]]; then
      print -u2 -- "invalid TCP port: $port"
      return 2
    fi
  done
  for port in "$@"; do
    # lsof exits 1 when nothing matches; no process is a successful no-op.
    pids=$(lsof -ti "tcp:$port")
    if [[ -n $pids ]]; then
      kill -- ${(f)pids} || return
    fi
  done
}

# Runtime dependencies matching any supplied regex; no args lists them all.
# Tab-separated package, dependency, version (rather than a Nushell table).
pjs() {
  local files file
  files=$(fd --type f --glob package.json) || return
  for file in "${(@f)files}"; do
    [[ -n $file ]] || continue
    jq -r --arg pattern "(${(j:|:)@})" '
      .name as $package | (.dependencies // {}) | to_entries[]
      | select(.key | test($pattern))
      | [$package, .key, .value] | @tsv
    ' "$file" || return
  done
}
