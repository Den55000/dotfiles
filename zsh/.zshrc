# ── History ──────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_VERIFY
setopt AUTO_CD INTERACTIVE_COMMENTS

# ── Completion ───────────────────────────────────────────────────────
fpath=(/usr/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{11}-- %d --%f'

# ── Key bindings ─────────────────────────────────────────────────────
bindkey -e   # emacs-style line editing

# Treat only alphanumerics as word characters, so Ctrl+Backspace eats
# one path segment / one word at a time instead of the whole argument.
autoload -Uz select-word-style && select-word-style bash

bindkey '^H'        backward-kill-word   # Ctrl+Backspace  (kitty sends \x08)
bindkey '^[[3;5~'   kill-word            # Ctrl+Delete
bindkey '^[[1;5D'   backward-word        # Ctrl+Left
bindkey '^[[1;5C'   forward-word         # Ctrl+Right
bindkey '^[[H'      beginning-of-line    # Home
bindkey '^[[F'      end-of-line          # End
bindkey '^[[3~'     delete-char          # Delete
bindkey '^[[A'      history-search-backward
bindkey '^[[B'      history-search-forward

# ── PowerShell / PSReadLine-style syntax colors ──────────────────────
# Colors mirror PSReadLine's defaults against the Campbell palette.
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[default]='fg=7'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=9,bold'          # Error
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=10'              # Keyword
ZSH_HIGHLIGHT_STYLES[command]='fg=11'                    # Command
ZSH_HIGHLIGHT_STYLES[builtin]='fg=11'
ZSH_HIGHLIGHT_STYLES[function]='fg=11'
ZSH_HIGHLIGHT_STYLES[alias]='fg=11'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=11'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=11'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=11'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=8'        # Parameter
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=8'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=6'      # String
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=6'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=6'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=6'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=10'   # Variable
ZSH_HIGHLIGHT_STYLES[assign]='fg=10'
ZSH_HIGHLIGHT_STYLES[named-fd]='fg=10'
ZSH_HIGHLIGHT_STYLES[comment]='fg=2'                     # Comment
ZSH_HIGHLIGHT_STYLES[path]='fg=15'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=14'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=8'                 # Operator
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=8'
ZSH_HIGHLIGHT_STYLES[bracket-level-1]='fg=8'
ZSH_HIGHLIGHT_STYLES[bracket-level-2]='fg=8'
ZSH_HIGHLIGHT_STYLES[bracket-level-3]='fg=8'

# ── Plugins (syntax-highlighting must come before autosuggestions) ───
# Arch keeps plugins under /usr/share/zsh/plugins, Debian/Ubuntu directly under /usr/share
for _p in zsh-syntax-highlighting zsh-autosuggestions; do
    for _d in /usr/share/zsh/plugins/$_p /usr/share/$_p; do
        [ -f $_d/$_p.zsh ] && { source $_d/$_p.zsh; break; }
    done
done
unset _p _d
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#767676'             # InlinePrediction
bindkey '^[[1;5C' forward-word   # re-assert after plugin widget wrapping

# ── Aliases ──────────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -lah'

# ── Prompt ───────────────────────────────────────────────────────────
command -v starship >/dev/null && eval "$(starship init zsh)"

# ── Dotfiles ─────────────────────────────────────────────────────────
# Says "dotfiles: N behind" when another machine pushed changes; see ~/dotfiles/README.md
command -v dots >/dev/null && dots check

# Machine-only aliases and settings (not in git)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
