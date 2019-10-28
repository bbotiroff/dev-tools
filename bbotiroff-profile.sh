#!/bin/bash

export PS1="\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\w/\[\033[33;1m\]\$(parse_current_branch)\[\033[00m\]\[\033[m\]\\n$ "
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

parse_current_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

gpush() {
  git push --set-upstream origin $(git branch | grep \* | cut -d ' ' -f2)
}

alias ll='ls -la'
alias gs='git status'
alias gb='git branch'

echo "bbotiroff-profile shell is loaded for $(whoami)"