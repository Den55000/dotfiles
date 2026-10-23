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
| `vscodium/`     | `settings.json`, `keybindings.json` linked into `%APPDATA%\VSCodium\User` (Windows); `extensions.txt` from `codium --list-extensions`, reinstall with `xargs -n1 codium --install-extension < extensions.txt` |
| `zed/`          | `settings.json`, `keymap.json` linked into `%APPDATA%\Zed` (Windows) |
| `windows-terminal/` | `settings.json` linked into `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState` (Windows); Ctrl+Tab switches tabs in most-recently-used order (`tabSwitcherMode: mru`) |
| `notepad++/`    | not linked, copy of `%APPDATA%\Notepad++` (Windows); `config.xml` has the recent-files and search history stripped |
| `powertoys/`    | not linked, copy of `%LOCALAPPDATA%\Microsoft\PowerToys` settings (no logs, history or per-monitor state); `CommandPalette/` is from the Command Palette package's `LocalState` |
| `wallpapers/`   | not linked; one background per environment, referenced by absolute path (`C:\Users\Denys\dotfiles\wallpapers\…`): `code-editor.jpg` (VSCodium), `desktop.jpg` (Windows), `browser.jpg` (LibreWolf new tab: uploaded by hand, the profile keeps its own copy), `launcher.jpg` (Command Palette), `terminal.jpg` (Windows Terminal) |
| `themes/`       | not linked; `palettes.json` is the source for the themes: Default (VSCodium's own Dark Modern with the original pictures) and five of mine, Soft Paper, Cold Stone, Midnight, Blue Skies and Dark Forest (based on Flexoki Light, Nord, Kanagawa Dragon, Tokyo Night Day and Everforest Dark). `build.py` generates the VSCodium theme extension (`themes/vscodium/`, packed to the git-ignored `themes/dist/dotfiles-themes.vsix`; install with `codium --install-extension themes/dist/dotfiles-themes.vsix --force`) and, with `build.py wallpapers` (needs Pillow + numpy), `wallpapers/themes/<theme>/<app>.jpg`: every app keeps its own picture, recoloured per theme. The code editor's starry night is repainted as a time of day by `scene.py` (Morning, Winter morning, Night, Day, Forest dusk; the specs are under each theme's `wallpapers` in `palettes.json`), the other apps are gradient-mapped onto the theme's `stops`. `apply.py <theme>` switches VSCodium's colour theme and background; `apply.py restore` goes back to `themes/baseline/vscodium-settings.json` (`--full` restores the whole file) |
| `windows/install-apps.ps1` | not linked; reinstalls my Windows apps with winget (`-DryRun` to preview) and lists the ones to install by hand |
| `windows/lan-mouse/` | not linked; `install.ps1` downloads the Lan Mouse release zip into `%LOCALAPPDATA%\Programs\lan-mouse`, builds the tray helper (`lan-mouse-tray.cs`, with the Windows .NET Framework `csc`) and adds a "Lan Mouse" Start menu shortcut to it. The helper keeps `lan-mouse daemon` running after the window is closed; quit from the tray icon. While it runs, Ctrl+Alt+Up switches to the other laptop (it pushes the cursor through the top edge, where that laptop is configured). The release shortcut is set to Ctrl+Alt+Down (`release_bind` in `%LOCALAPPDATA%\lan-mouse\config.toml`); the pairing in that config stays per machine |
| `windows/office-config.xml` | not linked; Office Deployment Tool config for Word, Excel and PowerPoint only (Microsoft 365 Business Standard) |

## New machine

```sh
git clone git@github.com:Den55000/dotfiles.git ~/dotfiles   # or https:// with `gh auth login`
~/dotfiles/install.sh
```

Anything already at a target path is moved to `<name>.bak-dotfiles-<date>`.
On Windows, run `install.sh` from Git Bash with Developer Mode on (needed for
real symlinks); there it only links the VSCodium, Zed and Windows Terminal configs.
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
