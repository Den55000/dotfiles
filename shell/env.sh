# Shared environment for bash AND zsh.
# POSIX sh only: no arrays, no [[ ]], no shell-specific syntax.
# Sourced by ~/.zshenv and ~/.bashrc. Put PATH and exported vars here,
# never aliases, prompts, or interactive settings.
# Machine-only vars go in ~/.config/shell/env.local.sh (not in git).

# Prepend a directory to PATH if it exists and isn't already there.
_path_prepend() {
    [ -d "$1" ] || return 0
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

export PNPM_HOME="$HOME/.local/share/pnpm"

_path_prepend "$PNPM_HOME/bin"
_path_prepend "$HOME/bin"
_path_prepend "$HOME/.local/bin"

[ -f "$HOME/.config/shell/env.local.sh" ] && . "$HOME/.config/shell/env.local.sh"

unset -f _path_prepend
export PATH
