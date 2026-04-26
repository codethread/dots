#---------------------------------------------#
# EDITOR-ish
# -------------------------------------------#
alias v="nvim"
alias zz="nvim ${ZDOTDIR}/.zshrc"
alias vv="cd ${DOTFILES}/.config/nvim; nvim ./init.lua" # open vim config
alias aa="nvim ~/.aliases.zsh"                          # open aliases
# see https://github.com/wbthomason/packer.nvim/issues/180 for MACOSX_DEPLOYMENT_TARGET=10.15
alias nvim-boot="MACOSX_DEPLOYMENT_TARGET=10.15 nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'"

alias zr="source ${ZDOTDIR}/.zshrc"
alias vo="nvim \$(fzf)"
alias als="eval \$(cat ~/.aliases.zsh | grep \"^alias.\+=\\\"\" | fzf -i --header='[run:]' | sed -E \"s:alias.*\\\"(.*)\\\":\\1:\" )"

#---------------------------------------------#
# EMACS
# -------------------------------------------#
alias emacs-doom="rm ~/.emacs.d; ln -s ~/doom-emacs ~/.emacs.d"
alias emacs-adam="rm ~/.emacs.d; ln -s ~/emacs ~/.emacs.d"
alias emacs-min="rm ~/.emacs.d; ln -s ~/emacs-minimal ~/.emacs.d"

alias ec="emacsclient -a \"\" -c -t"
alias ed="emacs --daemon"
alias eg="/Applications/Emacs.app/Contents/MacOS/Emacs"

#---------------------------------------------#
# KITTY
# -------------------------------------------#
alias ktt="kitty +kitten themes"
alias ktt-dark="kitty +kitten themes --reload-in=all Tokyo Night Storm"
alias ktt-light="kitty +kitten themes --reload-in=all Tokyo Night Day"

#---------------------------------------------#
# HELPERS
# -------------------------------------------#
alias grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn}'

alias ls='ls -pGF --color=auto'
# alias l='ls -lah'
alias l='exa -lah --icons'
alias lt='exa -1ah --tree'

alias pathis='echo $PATH | tr -s ":" "\n"'
alias portsinuse="lsof -i -p | grep -i 'listen'"
alias ports="echo lsof -i tcp:3000"
alias finder='open -a 'Finder' .'
alias screen='export TERM=screen-256color && screen'
alias treee='tree src -I "*~"'

#---------------------------------------------#
# RUNNERS
# -------------------------------------------#
alias alert="osascript -e 'display notification \"Task Finished\" with title \"CMD\"'; afplay /System/Library/Sounds/Glass.aiff"
alias ser='python -m SimpleHTTPServer $1' # start server
alias nn='netlify'

#---------------------------------------------#
# HOMEBREW
# -------------------------------------------#
alias bi="brew install"
alias brewup='brew update; brew doctor; brew upgrade; brewclean'
alias brewclean='brew cleanup; brew autoremove'
alias brewdeps="brew deps --graph --installed"

alias bbd="brew bundle dump"    # update brewfile
alias bbc="brew bundle check"   # ensure all installed
alias bbx="brew bundle cleanup" # removed unlisted
alias bbi="brew bundle install"

#---------------------------------------------#
# RARE USE
# -------------------------------------------#
alias mkssh="openssl rsa -in ~/.ssh/id_rsa | openssl base64 | tr -d '\n' | pbcopy"
alias pipes="pipes.sh -f 60 -s 8"

#---------------------------------------------#
# QMK
# -------------------------------------------#
alias qmk-print="qmk c2json keymap.c -km codethread -kb preonic/rev3_drop --no-cpp"

#---------------------------------------------#
# NODE
# -------------------------------------------#
alias npc="rm -rf ./node_modules; npm cache clear; npm i"
alias npl="npm -g ls --depth=0"
alias yy="eval \$(cat package.json | jq -S '.scripts' | sed '1d;$d' | fzf -i --header='[run:]' | sed -E \"s/\\\"(.*)\\\":.*/yarn run \\1/\" )"
alias rn-nuke="gnuke && yarn && cd ios && pod install && cd .. && yarn run-ios --reset-cache"
alias pp="pnpm"

#---------------------------------------------#
# DOCKER
# -------------------------------------------#
alias dock_ri='docker rmi $(docker images -a --filter=dangling=true -q)'                 #docker_clean_images
alias dock_rc='docker rm $(docker ps --filter=status=exited --filter=status=created -q)' #docker_clean_ps
alias dock_prune='docker system prune -a'
alias dcup='docker-compose up'
alias dcdn='docker-compose down'
alias dick="docker ps | grep '[a-z0-9]' | awk '{ print $1 }' | xargs docker kill"
alias dc="docker-compose config --services | fzf --multi | tr '\n' ' ' | xargs docker-compose up"

alias k8='kubectl'

#---------------------------------------------#
# GOLANG
# -------------------------------------------#
alias gob=go1.18beta1

#---------------------------------------------#
# GIT
# -------------------------------------------#
alias -g gbranch='git rev-parse --abbrev-ref HEAD'
alias -g gtrunk="git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'"
alias gclean="git clean -dfX"
alias gcp="git cherry-pick"
alias gst="git status -s"
alias gfuck='git fetch origin; git reset --hard origin/$(gbranch)'
alias gignore="git rm -r --cached .; git add .; git commit -m '.gitignore is now working'"
alias gkill='git branch | grep -v "$( gtrunk )" | xargs git branch -D'
alias gl='git log --oneline $( gtrunk )...HEAD'
alias grr="git log --oneline $(gtrunk)...HEAD | wc -l | xargs -I {} git rebase -i HEAD~{}"
# alias gmm='git checkout $( gtrunk ) && git pull && git checkout - && git rebase $( gtrunk )'
alias gmm='git fetch origin $(gtrunk):$(gtrunk) && git rebase $( gtrunk )'
alias gnah="git reset --hard; git clean -df"
alias gnuke="git clean -dfX"
alias gr='git rebase -i HEAD~$1'
alias gundo="git reset --soft HEAD~1 && git restore --staged ."
alias gwip="git add . && git commit -nm 'wip'"
alias gpopular="git log --format=format: --name-only --since=12.month | egrep -v '^$' | sort | uniq -c | sort -nr | head -50"
alias gbranch-mine="git for-each-ref --format=' %(authorname) %09 %(refname)' --sort=authorname | grep 'adam.hall'"
alias gconflict="git diff --name-only --diff-filter=U --relative"
alias gcache-clear="git rev-parse --show-toplevel | rargs rm -rf {0}/.git/rr-cache" # https://stackoverflow.com/questions/18500016/undo-a-git-rerere-resolution-that-was-done-in-a-rebase

# create a new branch from trunk
gnew() {
  if [ $# -eq 0 ]; then
    echo "No arguments supplied"
  else
    echo "Creating branch $1"
    git fetch origin $(gtrunk):$(gtrunk)
    git checkout -b "$1" $(gtrunk)
    # don't want to push to gtrunk
    git branch --unset-upstream
  fi
}

# worktree
alias gw="git worktree"

#---------------------------------------------#
# OS
#---------------------------------------------#
alias mac-dark-toggle="osascript -e 'tell app \"System Events\" to tell appearance preferences to set dark mode to not dark mode'"

#---------------------------------------------#
# TMUX
# -------------------------------------------#
alias tmux-delete-resurrect="rm ~/.local/share/tmux/resurrect/*"

##############################################
# work
##############################################
alias nvm="volta pin node@14 && volta pin yarn@1.22.4"
alias react-native-clean="git pull && gclean && yarn && yarn install:app && yarn run-ios --simulator \"iPhone SE (3rd generation)\""
