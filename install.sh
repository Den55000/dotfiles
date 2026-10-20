#!/bin/sh
# Link the dotfiles into place. Safe to run again: correct links are left
# alone, anything else in the way is moved to <name>.bak-dotfiles-<date>.
set -eu

DOT=$(cd "$(dirname "$0")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)

link() {
    src="$DOT/$1" dst="$2"
    [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ] && return 0
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mv "$dst" "$dst.bak-dotfiles-$STAMP"
        echo "  moved old $dst to $dst.bak-dotfiles-$STAMP"
    fi
    ln -s "$src" "$dst"
    echo "  linked $dst"
}

# Windows (Git Bash): only the app configs. Needs Developer Mode for real
# symlinks; nativestrict makes ln fail instead of silently copying.
case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*)
    export MSYS=winsymlinks:nativestrict
    APPDATA_U=$(cygpath -u "$APPDATA")
    link vscodium/settings.json    "$APPDATA_U/VSCodium/User/settings.json"
    link vscodium/keybindings.json "$APPDATA_U/VSCodium/User/keybindings.json"
    link zed/settings.json         "$APPDATA_U/Zed/settings.json"
    link zed/keymap.json           "$APPDATA_U/Zed/keymap.json"
    exit 0
    ;;
esac

# Shell
link zsh/.zshrc    "$HOME/.zshrc"
link zsh/.zshenv   "$HOME/.zshenv"
link bash/.bashrc  "$HOME/.bashrc"
link shell/env.sh  "$HOME/.config/shell/env.sh"

# Neovim: the whole directory. `style` writes theme.lua into it (git-ignored);
# keep the machine's current one if the old directory had it.
link nvim "$HOME/.config/nvim"
if [ ! -e "$DOT/nvim/theme.lua" ] && [ -f "$HOME/.config/nvim.bak-dotfiles-$STAMP/theme.lua" ]; then
    cp "$HOME/.config/nvim.bak-dotfiles-$STAMP/theme.lua" "$DOT/nvim/theme.lua"
fi

# Kitty: only on machines that have it. Individual files, because `style`
# writes colors-active.conf next to them.
if command -v kitty >/dev/null 2>&1; then
    link kitty/kitty.conf           "$HOME/.config/kitty/kitty.conf"
    link kitty/colors-campbell.conf "$HOME/.config/kitty/colors-campbell.conf"
    [ -e "$HOME/.config/kitty/colors-active.conf" ] ||
        cp "$DOT/kitty/colors-campbell.conf" "$HOME/.config/kitty/colors-active.conf"
fi

# The `dots` helper
link bin/dots "$HOME/.local/bin/dots"
