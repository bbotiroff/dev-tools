autoload -U colors && colors

source $BBOTIROFF_DEV_TOOL_PATH/shortcutsrc
source $BBOTIROFF_DEV_TOOL_PATH/aliasrc
source $BBOTIROFF_DEV_TOOL_PATH/git-shortcuts.sh
source $BBOTIROFF_DEV_TOOL_PATH/worktree-cli.sh

function parse_git_branch() {
    git branch 2> /dev/null | sed -n -e 's/^\* \(.*\)/[\1]/p'
}

function basede() {
    echo $1 | base64 -Dd
}

function baseen() {
    echo $1 | base64
}

setopt prompt_subst
NEW_LINE=$'\n'
PS1='%B%{$fg[cyan]%}%n%{$fg[white]%}@%{$fg[green]%}%~%{$fg[yellow]%} $(parse_git_branch)%b$NEW_LINE%{$fg[white]%}%B$%b '

# History in cache directory
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# Basic auto/tab complete
autoload -U compinit
zstyle ':comletion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)

source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

echo "bbotiroff-profile shell is loaded for $(whoami)"