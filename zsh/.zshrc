autoload -U colors && colors

# Source dev-tools configuration files with error handling
[[ -f "$BBOTIROFF_DEV_TOOL_PATH/shortcutsrc" ]] && source $BBOTIROFF_DEV_TOOL_PATH/shortcutsrc
[[ -f "$BBOTIROFF_DEV_TOOL_PATH/aliasrc" ]] && source $BBOTIROFF_DEV_TOOL_PATH/aliasrc
[[ -f "$BBOTIROFF_DEV_TOOL_PATH/git-shortcuts.sh" ]] && source $BBOTIROFF_DEV_TOOL_PATH/git-shortcuts.sh
[[ -f "$BBOTIROFF_DEV_TOOL_PATH/worktree-cli.sh" ]] && source $BBOTIROFF_DEV_TOOL_PATH/worktree-cli.sh

function parse_git_branch() {
    local branch=$(git branch 2> /dev/null | sed -n -e 's/^\* \(.*\)/\1/p')
    if [[ -n $branch ]]; then
        # Check if there are uncommitted changes
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            echo "[%{$fg[red]%}$branch%{$fg[yellow]%}*%{$reset_color%}]"
        else
            echo "[%{$fg[green]%}$branch%{$reset_color%}]"
        fi
    fi
}

function basede() {
    echo $1 | base64 -Dd
}

function baseen() {
    echo $1 | base64
}

setopt prompt_subst
NEW_LINE=$'\n'
# Enhanced colorized prompt
PS1='%{$fg_bold[cyan]%}%n %{$fg_bold[blue]%}%~%{$reset_color%} $(parse_git_branch)$NEW_LINE%{$fg_bold[white]%}$ %{$reset_color%}'

# History in cache directory
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# Basic auto/tab complete with colors
autoload -U compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:*:*:*:descriptions' format '%F{green}-- %d --%f'
zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zmodload zsh/complist
compinit
_comp_options+=(globdots)


# Enable colors for common commands
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad
alias ls='ls -G'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'

# Colored grep output
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Color support for less and man pages
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# echo "bbotiroff-profile shell is loaded for $(whoami)"