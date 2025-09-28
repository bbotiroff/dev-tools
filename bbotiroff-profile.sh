#!/bin/bash

source $BBOTIROFF_DEV_TOOL_PATH/git-shortcuts.sh

export PS1="\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\w/\[\033[33;1m\]\$(parse_current_branch)\[\033[00m\]\[\033[m\]\\n$ "
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

alias ll='ls -la'

echo "bbotiroff-profile shell is loaded for $(whoami)"