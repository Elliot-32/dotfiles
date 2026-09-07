# Repository map

This is a routing guide, not a substitute for reading the current repository. Inspect the actual files before changing them because the repository evolves frequently.

## Core mise configuration

### `config.toml`

Primary global mise config. It currently owns:

- minimum mise version and global settings;
- GitHub credential behavior;
- PATH/editor environment;
- shell aliases;
- `[tools]` for mise-managed CLIs/runtimes;
- `[dotfiles]` mappings;
- bootstrap directories and mise shell activation;
- login shell configuration;
- user systemd units/timers, including Topgrade-driven unattended updates and gomi pruning;
- `tasks.bootstrap`, `bootstrap:windows`, and `update:fonts`;
- post-install completion synchronization.

`tasks.bootstrap` currently coordinates Atuin setup, mise completion installation, `mise-completions-sync`, Sheldon locking, Yazi plugin installation, hk setup, Nerd Font update, Windows bootstrap dispatch, and GitHub login.

The repo itself is intended to live at the mise global config directory (`~/.config/mise` by default).

### `miserc.toml`

Jinja-based environment selection. It currently detects:

- Arch;
- Fedora;
- RHEL-family;
- Ubuntu;
- Debian;
- graphical session presence for Flatpak configuration;
- WSL;
- WSLg.

It builds a mise environment list such as `ubuntu,apt,flatpak,wsl,wslg`.

When changing detection, preserve distro precedence. Ubuntu must not accidentally fall through to generic Debian, and Fedora/RHEL logic must remain intentional.

## Conditional configuration

### `conf.d/distro.ubuntu.toml`
Ubuntu-only behavior, currently including Ubuntu-specific Ghostty bootstrap/repository setup.

### `conf.d/distro.fedora.toml`
Fedora-only behavior, currently including Fedora-specific Ghostty bootstrap/repository setup.

### `conf.d/packages.apt.toml`
APT-family package-manager configuration shared where appropriate by Ubuntu and Debian.

### `conf.d/packages.dnf.toml`
DNF-family package-manager configuration shared where appropriate by Fedora and RHEL-family systems.

### `conf.d/packages.pacman.toml`
Pacman/Arch package-manager configuration.

### `conf.d/platform.wsl.toml`
WSL-specific configuration. It selects the WSL Sheldon profile and runs the Windows bootstrap through `powershell.exe` from the final bootstrap hook when Windows interop is available.

### `conf.d/platform.wslg.toml`
WSLg-specific configuration.

### `config.flatpak.toml`
Flatpak-specific packages/bootstrap/update behavior selected via the `flatpak` environment.

## Shell and dotfiles

### `.zshenv`
Very early Zsh environment. Keep it minimal.

### `.zprofile`
Login-shell initialization.

### `.zshrc`
Interactive shell behavior. Before adding initialization here, check whether mise or Sheldon already owns it.

### `.p10k.zsh`
Powerlevel10k prompt configuration.

### `.config/sheldon/plugins.toml`
Zsh plugin manager configuration and inline initialization.

Important current ordering constraints:

- mise and synchronized completion directories are added to `fpath` before `compinit`;
- `zsh-completions` contributes to `fpath`;
- `compinit` runs before zoxide/atuin integrations;
- `fzf-tab` loads after `compinit`;
- widget-wrapping plugins follow as appropriate;
- `zsh-syntax-highlighting` remains last among plugins.

### `.config/sheldon/plugins/`
Local Sheldon plugin content, including platform-specific helpers such as WSL notification behavior.

### `.config/yazi/`
Yazi configuration managed as dotfiles.

- `package.toml`: plugin manifest. Bootstrap installs declared dependencies with `ya pkg install`.
- `keymap.toml`: key bindings and plugin actions.
- `yazi.toml`: core Yazi configuration.
- `init.lua`: plugin initialization/runtime setup.

Keep plugin declarations in `package.toml`; avoid adding separate plugin-install scripts when Yazi's package manager already owns the dependency.

### `.config/topgrade.toml`
Interactive/default Topgrade configuration. Topgrade is the user-facing update orchestrator and deliberately disables ecosystems already managed by mise. It also runs the Nerd Font update task and refreshes mise-generated Zsh completions after updates.

### `.config/topgrade.systemd.toml`
Non-interactive Topgrade configuration used by the user systemd `update` service/timer. Keep unattended behavior separate from the interactive config where necessary.

### `.config/ghostty/`
Ghostty configuration.

### `.config/environment.d/`
Environment configuration for systemd/user-session consumers.

### `.config/fcitx5/`
Fcitx5 configuration.

### `.config/xdg-terminals.list`
XDG terminal preference data.

## Bundled assets

### `assets/windows-terminal/catppuccin/`
Pinned Catppuccin Windows Terminal assets used by the WSL Windows bootstrap. `mocha.json` provides the Catppuccin Mocha color scheme and `mochaTheme.json` provides the matching Windows Terminal UI theme. Keep these files vendored so bootstrap does not depend on fetching Catppuccin's `main` branch at runtime.

## Imperative scripts

### `scripts/bootstrap-flatpak.sh`
Flatpak bootstrap logic that is not represented solely by declarative config.

### `scripts/bootstrap-ghostty-ubuntu.sh`
Ubuntu-specific Ghostty repository/bootstrap helper.

### `scripts/bootstrap-ghostty-fedora.sh`
Fedora-specific Ghostty repository/bootstrap helper.

### `scripts/bootstrap-windows.ps1`
Windows-native bootstrap invoked from WSL through `powershell.exe`. It currently uses WinGet to ensure Windows Git and JetBrainsMono Nerd Font are installed, then idempotently injects the bundled Catppuccin Mocha color scheme/theme into Windows Terminal, selects them as the default profile color scheme and application theme, sets the default Nerd Font, and preserves a one-time settings backup.

Keep Windows package and Windows Terminal manipulation here instead of mixing it into Linux package-manager configuration.

### `scripts/update-fonts.sh`
Linux Nerd Font updater used by `mise run update:fonts`. It skips Linux font installation under WSL, resolves the latest JetBrainsMono Nerd Font release, verifies the release checksum manifest, swaps the installed font directory safely, and refreshes the font cache.

### `scripts/login-github.sh`
Interactive/nontrivial GitHub login/configuration workflow used by bootstrap.

Prefer extending native mise configuration first. Keep shell and PowerShell scripts focused and idempotent where possible.

## Quality and CI

### `hk.pkl`
Pre-commit/check definitions. Current checks include:

- ShellCheck for shell files;
- `sh -n` for `scripts/*.sh`;
- `zsh -n` for `.zshrc` and `.p10k.zsh`.

PowerShell is not currently covered by hk, so changes to `scripts/bootstrap-windows.ps1` need an explicit parser/syntax check when PowerShell is available.

### `.github/workflows/ci.yml`
Ubuntu CI that validates:

- hk/static checks;
- mise settings;
- mise task validity;
- locked bootstrap dry-run;
- environment/config selection for Ubuntu/APT, Debian/APT, Fedora/DNF, RHEL/DNF, Arch/Pacman, and Flatpak.

### `mise.lock`
Generated mise lockfile. Do not hand edit.

### `README.md`
User-facing installation and maintenance commands. Update it when commands or externally visible behavior change.
