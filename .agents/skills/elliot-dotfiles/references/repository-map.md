# Repository map

This is a routing guide, not a substitute for reading the current repository. Inspect the actual files before changing them because the repository evolves frequently.

## Setup repository layout

This repository is a mise setup repository, not a checkout intended to live at `$MISE_CONFIG_DIR`.

- `.mise-history/` contains the setup marker and portable enrollment metadata.
- `config/` is the portable representation of the active mise global configuration directory and is restored to `$MISE_CONFIG_DIR`.
- `home/` is the portable representation of tracked native user files and is restored under `$HOME`.
- mise keeps shared history in its own bare store; `config.local.toml`, credentials, and other machine-local state stay outside the shared setup tree.

## Core mise configuration

### `config/config.toml`
Primary global mise config. It owns global settings, tools, native tracking declarations, bootstrap resources, user units/timers, tasks, hooks, and the remaining declarative dotfile edits.

JetBrainsMono Nerd Font is declared as a mise-managed GitHub release tool. Its inline tool-level `postinstall` symlinks the extracted font directory into the user font directory and refreshes Linux fontconfig on Linux hosts, including WSL. Windows font installation is handled separately by the WSL Windows bootstrap task.

`tasks.bootstrap` coordinates Atuin setup, completion installation/sync, Sheldon locking, Yazi plugin installation, Windows font bootstrap dispatch, Tinty/Omarchy theme bootstrap, and GitHub setup. It does not install a Git hook into `$MISE_CONFIG_DIR` because that directory is no longer a Git working tree.

### `config/miserc.toml`
Global early-init environment selector restored to `$MISE_CONFIG_DIR/miserc.toml`. It enables environment-specific `conf.d` filenames, detects Arch, Fedora, RHEL-family, Ubuntu, Debian, graphical-session/Flatpak capability, WSL, and WSLg, then selects environments such as `ubuntu,apt,flatpak,fcitx-flatpak,wsl,wslg` regardless of the current working directory. `fcitx-flatpak` is selected only for non-Arch graphical systems; Arch uses the native Pacman/AUR Fcitx stack. The selector body is intentionally wrapped in an inert `_` multiline string that Tera removes before miserc parsing; this keeps mise 2026.9.11 setup-history preflight from interpreting the early-init `env = [...]` selector as an ordinary mise environment table.

## Conditional configuration

- `config/conf.d/distro.ubuntu.toml`: Ubuntu-specific Ghostty package/repository bootstrap.
- `config/conf.d/distro.fedora.toml`: Fedora-specific Ghostty package/repository bootstrap.
- `config/conf.d/packages.apt.toml`: APT-family packages/settings, including native Fcitx5 host integration modules.
- `config/conf.d/packages.dnf.toml`: DNF-family packages/settings, including native Fcitx5 host integration modules.
- `config/conf.d/packages.pacman.toml`: Pacman/Arch packages/settings, including the native Fcitx5 daemon, host IM modules, McBopomofo via AUR, declarative removal of legacy theme packages and Chewing, and the pre-package AUR-helper bootstrap.
- `config/conf.d/platform.laptop.toml`: opt-in laptop keyboard profile; manages the system-wide keyd mapping only when the `laptop` environment is explicitly selected.
- `config/conf.d/platform.omarchy.toml`: Omarchy-specific tracked hooks, Topgrade config deployment, and theme/bootstrap compatibility behavior.
- `config/conf.d/platform.wsl.toml`: WSL behavior and Windows font/bootstrap integration override.
- `config/conf.d/platform.wslg.toml`: WSLg-specific configuration.
- `config/config.flatpak.toml`: general Flatpak bootstrap/update behavior and application package declarations.
- `config/config.fcitx-flatpak.toml`: non-Arch graphical Fcitx profile; owns the Flatpak Fcitx 5 daemon, McBopomofo extension, and user XDG autostart entry.

## Native tracked dotfiles

These files are restored directly to their application paths and use `mode = "track"`; there is no intermediate symlink source in `$MISE_CONFIG_DIR`:

- `home/.zshrc`, `home/.zshenv`, `home/.zprofile`, `home/.p10k.zsh`;
- `home/.config/sheldon/`;
- `home/.config/yazi/`;
- `home/.config/topgrade.systemd.toml`;
- `home/.config/ghostty/config`;
- `home/.config/herdr/config.toml`;
- `home/.config/omarchy/themed/gomi.yaml.tpl`, `home/.config/omarchy/themed-links.toml`, `home/.config/omarchy/hooks/theme-set.d/50-themed-links`, and `home/.config/omarchy/hooks/post-update.d/90-remove-mise-wrappers`;
- `home/.config/xdg-terminals.list`;
- `home/.config/fcitx5/profile`;
- `home/.config/environment.d/90-fcitx5.conf`;
- `home/.local/share/mise-completions-sync/registry.toml`.

Herdr's tracked config routes agent completion/input notifications through the outer terminal with `[ui.toast] delivery = "terminal"`. Fcitx5 user configuration is shared across Linux systems; Arch owns the daemon and McBopomofo engine natively, while non-Arch graphical systems use the dedicated Flatpak Fcitx profile and distro packages retain host IM modules. Catppuccin and Mellow themes are user-managed consistently across both paths. `~/.gitconfig` is managed only through a block edit so machine-local identity is not synchronized.

## Bundled assets and scripts

- `config/assets/keyd/laptop.conf`: keyd mapping used by the opt-in laptop profile (`Print` as Super, `Ctrl+Print` as PrintScreen).
- `config/assets/topgrade.toml`: shared Topgrade config deployed to `~/.config/topgrade.toml` on normal systems; the deployment target is intentionally not history-tracked.
- `config/assets/topgrade.omarchy.toml`: Omarchy-specific Topgrade config deployed to the same target; delegates the system update step to `omarchy update` while keeping the rest of the Topgrade workflow.
- `config/scripts/bootstrap-flatpak.sh`: Flatpak bootstrap helper.
- `config/scripts/bootstrap-paru.sh`: Arch pre-package helper that installs Paru only when neither Paru nor Yay is already available.
- `config/scripts/sync-fcitx5-themes.sh`: syncs Catppuccin and Mellow from GitHub, enables Catppuccin rounded borders, and installs them for native and Flatpak Fcitx5. Topgrade calls the same helper for updates.
- `config/scripts/bootstrap-ghostty-ubuntu.sh`: Ubuntu Ghostty helper.
- `config/scripts/bootstrap-ghostty-fedora.sh`: Fedora Ghostty helper.
- `config/scripts/bootstrap-windows.sh`: WSL-side wrapper that installs the Windows JetBrainsMono Nerd Font only.
- `config/scripts/bootstrap-windows.ps1`: Windows-native WinGet font installer.
- `config/scripts/bootstrap-windows-terminal.sh`: WSL-side Windows Terminal integration for keybindings and terminal-native notifications.
- `config/scripts/tinty-windows-terminal.sh`: Tinty-side Windows Terminal integration; writes `tinty.json`, registers its JSONC import, and removes legacy `palette.json` state.
- `config/scripts/ensure-windows-terminal-import.cjs`: JSONC editor used by Windows Terminal integration helpers.
- `config/scripts/tinty-theme-picker.sh`: platform-independent Gum-based Tinty scheme picker with apply/restore preview flow.
- `config/scripts/login-github.sh`: GitHub login/configuration workflow.

Prefer native mise configuration first; keep scripts focused and idempotent where imperative/platform-native behavior is required.

## Quality and CI

### `config/hk.pkl`
Fast local/static validation only: shellcheck plus shell, PowerShell, Zsh, and extensionless Omarchy-hook syntax checks.

### `.github/workflows/ci.yml`
CI runs hk, validates mise parsing and the bootstrap plan, checks the small set of platform/profile contracts that materially change behavior, verifies environment selection, and performs fresh-user onboarding with a non-default `MISE_CONFIG_DIR`.

### `config/mise.lock`
Generated mise lockfile. Do not hand edit.

### `README.md`
User-facing installation, migration, sync, and maintenance workflow.
