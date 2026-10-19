# dotfiles

Shell (zsh, bash, shared env), Neovim and kitty config, shared between
machines with git. Each machine has a clone at `~/dotfiles`; the real config
paths are symlinks into it, so editing `~/.zshrc` or `~/.config/nvim/init.lua`
edits the repo.

| Repo            | Linked to                                   |
|-----------------|---------------------------------------------|
| `zsh/.zshrc`    | `~/.zshrc`                                  |
| `zsh/.zshenv`   | `~/.zshenv`                                 |
| `bash/.bashrc`  | `~/.bashrc`                                 |
| `shell/env.sh`  | `~/.config/shell/env.sh` (PATH + env, POSIX sh, read by both shells) |
| `nvim/`         | `~/.config/nvim` (whole directory)          |
| `kitty/*.conf`  | `~/.config/kitty/` (only where kitty is installed) |
| `bin/dots`      | `~/.local/bin/dots`                         |
| `vscode/`       | not linked, kept as an archive              |
| `vscodium/`     | not linked, copy of `%APPDATA%\VSCodium\User` (`settings.json`, `keybindings.json`); `extensions.txt` from `codium --list-extensions`, reinstall with `xargs -n1 codium --install-extension < extensions.txt` |
| `notepad++/`    | not linked, copy of `%APPDATA%\Notepad++` (Windows); `config.xml` has the recent-files and search history stripped |
| `powertoys/`    | not linked, copy of `%LOCALAPPDATA%\Microsoft\PowerToys` settings (no logs, history or per-monitor state); `CommandPalette/` is from the Command Palette package's `LocalState` |
| `windows/install-apps.ps1` | not linked; reinstalls my Windows apps with winget (`-DryRun` to preview) and lists the ones to install by hand |

## New machine

```sh
git clone git@github.com:Den55000/dotfiles.git ~/dotfiles   # or https:// with `gh auth login`
~/dotfiles/install.sh
```

Anything already at a target path is moved to `<name>.bak-dotfiles-<date>`.
Needs zsh (+ zsh-syntax-highlighting, zsh-autosuggestions, starship are
optional) and Neovim 0.12+ (`vim.pack`). Plugins install on first nvim start,
pinned by `nvim/nvim-pack-lock.json`.

## Day to day

```sh
dots              # status
dots sync         # commit local edits, pull, push, re-link
dots sync "msg"   # same with a commit message
dots log / diff   # any git command runs inside ~/dotfiles
```

A new zsh prints `dotfiles: N change(s) behind` when another machine has
pushed; the check fetches in the background at most once a day. Nothing is
pulled automatically.

## Per-machine settings (not in git)

- `~/.config/shell/env.local.sh`: env vars (e.g. `BROWSER`)
- `~/.zshrc.local`: aliases, machine-only tools
- `~/.bashrc.local`

## Generated files (git-ignored)

The desktop's `style` colour switcher writes `nvim/theme.lua` and
`~/.config/kitty/colors-active.conf` on each machine. Without them nvim falls
back to tokyonight and kitty to the Campbell colours. nvim watches
`theme.lua` and recolours live; the laptop's `style` also pushes it to the
hosts in `~/.config/style/remotes`, so nvim over ssh follows the desktop theme.

## Treesitter parsers

Parsers are compiled, not config, and live in `~/.local/share/nvim/site`.
For a machine without a C compiler, copy them from one that has them:
`dots parsers <ssh-host>`.

## Changing the source of truth

`origin` is GitHub. To make a server the hub instead:

```sh
ssh cloud 'git init --bare ~/dotfiles.git'
git -C ~/dotfiles push cloud:dotfiles.git main          # seed it
git -C ~/dotfiles remote set-url origin cloud:dotfiles.git   # on each machine
```
