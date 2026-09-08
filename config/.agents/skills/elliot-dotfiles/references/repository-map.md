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
Primary global mise config. It owns global settings, tools, native tracking declarations, bootstrap resources, user units/timers, tasks, hooks, and the remaining declarative dotfile exceptions.

`tasks.bootstrap` coordinates Atuin setup, completion installation/sync, Sheldon locking, Yazi plugin installation, Nerd Font update, Windows bootstrap dispatch, and GitHub setup. It does not install a Git hook into `$MISE_CONFIG_DIR` because that directory is no longer a Git working tree.

### `home/.miserc.toml`
Environment selector restored to `~/.miserc.toml`. It detects Arch, Fedora, RHEL-family, Ubuntu, Debian, graphical-session/Flatpak capability, WSL, and WSLg, then selects environments such as `ubuntu,apt,flatpak,wsl,wslg`.

## Conditional configuration

- `config/conf.d/distro.ubuntu.toml`: Ubuntu-specific Ghostty package/repository bootstrap.
- `config/conf.d/distro.fedora.toml`: Fedora-specific Ghostty package/repository bootstrap.
- `config/conf.d/packages.apt.toml`: APT-family packages/settings and the conditional Fcitx5 declarative deployment.
- `config/conf.d/packages.dnf.toml`: DNF-family packages/settings.
- `config/conf.d/packages.pacman.toml`: Pacman/Arch packages/settings.
- `config/conf.d/platform.wsl.toml`: WSL behavior and interactive Windows bootstrap override.
- `config/conf.d/platform.wslg.toml`: WSLg-specific configuration.
- `config/config.flatpak.toml`: Flatpak-specific bootstrap/update behavior.

## Native tracked dotfiles

These files are restored directly to their application paths and use `mode = "track"`; there is no intermediate symlink source in `$MISE_CONFIG_DIR`:

- `home/.zshrc`, `home/.zshenv`, `home/.zprofile`, `home/.p10k.zsh`;
- `home/.config/sheldon/`;
- `home/.config/yazi/`;
- `home/.config/topgrade.toml` and `home/.config/topgrade.systemd.toml`;
- `home/.config/ghostty/config`;
- `home/.config/xdg-terminals.list`;
- `home/.local/share/mise-completions-sync/registry.toml`.

`config/conf.d/packages.apt.toml` intentionally keeps Fcitx5 `profile` and `environment.d/90-fcitx5.conf` as declarative sources under `config/.config/` so they are only deployed when the APT environment is selected. `~/.gitconfig` is also managed only through a block edit so machine-local identity is not synchronized.

## Bundled assets and scripts

- `config/assets/windows-terminal/`: vendored Windows Terminal color schemes/UI themes.
- `config/scripts/bootstrap-flatpak.sh`: Flatpak bootstrap helper.
- `config/scripts/bootstrap-ghostty-ubuntu.sh`: Ubuntu Ghostty helper.
- `config/scripts/bootstrap-ghostty-fedora.sh`: Fedora Ghostty helper.
- `config/scripts/bootstrap-windows.sh`: WSL-side interactive Gum entry point.
- `config/scripts/bootstrap-windows.ps1`: Windows-native WinGet/Windows Terminal setup.
- `config/scripts/update-fonts.sh`: Linux Nerd Font updater.
- `config/scripts/login-github.sh`: GitHub login/configuration workflow.

Prefer native mise configuration first; keep scripts focused and idempotent where imperative/platform-native behavior is required.

## Quality and CI

### `config/hk.pkl`
Static checks run with `config/` as the hk working directory. Shell scripts live under `config/scripts/`; Zsh files are checked through `../home/.zshrc` and `../home/.p10k.zsh`.

### `.github/workflows/ci.yml`
Ubuntu CI validates hk/static checks, PowerShell syntax, mise settings/tasks, locked bootstrap dry-run, setup-repository onboarding into an empty user with a custom `MISE_CONFIG_DIR`, native tracked paths, and distro/environment selection.

### `config/mise.lock`
Generated mise lockfile. Do not hand edit.

### `README.md`
User-facing installation, migration, sync, and maintenance workflow.
