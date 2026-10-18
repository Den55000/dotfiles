#
# ~/.bashrc  (from ~/dotfiles; zsh is the main shell, this is the fallback)
#

# Shared with zsh; see ~/.config/shell/env.sh
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend checkwinsize

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -lah'
PS1='[\u@\h \W]\$ '

if ! shopt -oq posix && [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi

# Machine-only settings (not in git)
[ -f ~/.bashrc.local ] && . ~/.bashrc.local
