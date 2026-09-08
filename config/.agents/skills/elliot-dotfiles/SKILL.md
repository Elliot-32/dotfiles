---
name: elliot-dotfiles
description: Maintain, review, and evolve Elliot-32/dotfiles, a mise-centric Linux/WSL setup repository. Use for work involving config.toml, miserc.toml, conf.d environment selection, mise tools/bootstrap/tasks, native tracked dotfiles, package managers, Flatpak, Zsh/Sheldon plugins and completions, Yazi, Topgrade, Ghostty, Fcitx5, Nerd Fonts, WSL/WSLg and Windows bootstrap, hk/CI, mise.lock, README updates, or repository refactors.
license: MIT
compatibility: Intended for Agent Skills-compatible coding agents working in a checkout of Elliot-32/dotfiles. Validation assumes git and mise; some checks additionally use zsh, hk, shellcheck, and PowerShell.
metadata:
  author: Elliot-32
  version: "1.3"
---

# Elliot dotfiles maintenance

Maintain this repository with minimal, architecture-consistent changes.

The user's explicit instructions take precedence over this skill. Do not turn a request for analysis into a repository mutation, and do not commit, push, open a PR, or merge unless the user asks for that action.

## Start every repository task

1. Inspect the current branch and working tree before editing.
2. Read the files that own the behavior being changed; do not rely only on this skill's repository snapshot.
3. Read [references/repository-map.md](references/repository-map.md) when the task crosses configuration layers or when file ownership is unclear.
4. Keep unrelated user changes intact.
5. For version-sensitive mise, shell-plugin, package-manager, completion-registry, Yazi-plugin, Topgrade, WinGet, or CI behavior, verify current upstream documentation when the answer depends on behavior not demonstrated by this repository.

## Architecture rules

- Treat setup-repository `config/` as the portable representation of the active mise global config directory; it is restored to `$MISE_CONFIG_DIR`, not checked out there as a Git working tree.
- Treat `config/config.toml` as the main mise global configuration. Keep generic settings, environment variables, tool declarations, tracking declarations, bootstrap definitions, systemd units, tasks, and hooks there unless they are conditional.
- Treat `home/.miserc.toml` as the environment selector restored to `~/.miserc.toml`. It detects distro/package-manager/platform capabilities and selects named mise environments.
- Route conditional mise configuration through `config/conf.d/`: `distro.*.toml` for distro behavior, `packages.*.toml` for package-manager behavior, and `platform.*.toml` for WSL/WSLg or other platform behavior.
- Keep Flatpak-specific configuration in `config/config.flatpak.toml`.
- Prefer declarative mise configuration over shell scripts. Add or extend a script only when the operation is inherently imperative, interactive, platform-native, or cannot be represented safely in mise configuration.
- Prefer native `mode = "track"` for ordinary user dotfiles. Keep them at the path applications actually read (`home/...` in the setup repository) instead of introducing source-to-target symlinks. Fcitx5 user configuration is shared this way across APT, DNF, and Pacman systems; use package-manager fragments only for installing the distro-specific packages. Use declarative copy/symlink/template/edit modes only when deployment semantics are genuinely needed, such as the managed `.gitconfig` block.
- Treat Topgrade as the user-session update orchestrator, while mise history/sync is the synchronization authority for tracked configuration and `mise.lock`. Do not add Git pull/push behavior that competes with history sync.
- Treat `home/.config/yazi/package.toml` as Yazi's plugin manifest. Bootstrap installs declared plugins with `ya pkg install`; change plugin declarations there rather than adding ad-hoc plugin install commands elsewhere.
- Treat `config/conf.d/platform.wsl.toml` plus `config/scripts/bootstrap-windows.ps1` as the WSL-to-Windows bootstrap path. Keep Windows-native WinGet/package/Windows Terminal behavior in PowerShell instead of moving it into Linux package configuration.
- Linux Nerd Font maintenance is owned by `tasks.update:fonts` and `config/scripts/update-fonts.sh`; Windows font installation is owned by `config/scripts/bootstrap-windows.ps1`. Preserve the intentional WSL split.
- Keep Zsh plugin and completion ordering in `home/.config/sheldon/plugins.toml` deliberate: completion directories on `fpath`, then `compinit`, integrations that require it, `fzf-tab` before widget-wrapping plugins, and syntax highlighting last.
- Prefer `nvim` for editor commands and examples; do not introduce `nano`.
- If a user-visible command, bootstrap behavior, installation flow, or maintenance workflow changes, update `README.md` in the same change.
- Treat `config/mise.lock` as generated state. Never hand-edit it. Only refresh it when the requested change requires lockfile changes, and review the diff for unrelated churn.

## Route common changes

Use [references/repository-map.md](references/repository-map.md) for details. In general:

- Add or remove a mise-managed CLI/tool: edit `[tools]` in `config/config.toml`.
- Add a distro package: edit the matching `config/conf.d/packages.<manager>.toml`.
- Add a distro-only repository or bootstrap prerequisite: edit the matching `config/conf.d/distro.<distro>.toml`.
- Add a Flatpak app/remote/bootstrap change: edit `config/config.flatpak.toml` and its existing bootstrap path.
- Change distro/platform detection: edit `home/.miserc.toml`, then extend CI selection checks.
- Change Zsh plugin loading, `fpath`, completion, widgets, or zstyle setup: inspect `home/.config/sheldon/plugins.toml` and `home/.zshrc`; place behavior in the layer that owns it rather than duplicating initialization.
- Change generated CLI completions: inspect `config/config.toml` hooks/tasks, `home/.local/share/mise-completions-sync/registry.toml`, and the current upstream `mise-completions-sync` registry before editing.
- Change shell startup environment: inspect `home/.zshenv`, `home/.zprofile`, `home/.zshrc`, Sheldon config, and mise shell activation before adding another initialization path.
- Add, remove, or configure a Yazi plugin: inspect `home/.config/yazi/package.toml`, `init.lua`, `keymap.toml`, and `yazi.toml`; keep plugin installation delegated to `ya pkg install`.
- Change Fcitx5 configuration: edit `home/.config/fcitx5/profile` or `home/.config/environment.d/90-fcitx5.conf`; change package availability separately in the APT, DNF, and Pacman package fragments.
- Change unattended/user-session update behavior: inspect `home/.config/topgrade.toml`, `home/.config/topgrade.systemd.toml`, and the `update` / `update-timer` systemd units in `config/config.toml` before adding another updater.
- Change Linux Nerd Font installation/update behavior: edit `config/scripts/update-fonts.sh` and the `update:fonts` task path in `config/config.toml`; preserve checksum verification and WSL skip behavior unless the change explicitly replaces that design.
- Change Windows packages, Windows Terminal defaults, or other WSL-triggered Windows setup: inspect `config/conf.d/platform.wsl.toml`, `tasks.bootstrap:windows`, and `config/scripts/bootstrap-windows.ps1`.
- Change bootstrap behavior: prefer existing `[bootstrap.*]`, `[tasks.*]`, and `[hooks]` in `config/config.toml`, including completion sync, Sheldon locking, Yazi package install, font update, Windows bootstrap, and GitHub login flow.
- Change validation checks: edit `config/hk.pkl` and, when necessary, `.github/workflows/ci.yml`.

## Completion registry rules

This repository uses `mise-completions-sync` for mise-managed CLI completions. The local overlay is `home/.local/share/mise-completions-sync/registry.toml`, directly tracked at its native path. Bootstrap runs `misecompsync --shell zsh`, and the post-install hook runs `misecompsync --new-only --shell zsh`.

When adding or changing completion support for a tool, use this priority order:

1. Check whether the tool already exists in the current upstream `mise-completions-sync` built-in registry. If it does, do not add a local entry unless the repository intentionally needs an override.
2. If the tool is not built in, check whether its completion command matches one of the built-in patterns. Prefer a short pattern entry such as `tool = "standard"` instead of duplicating shell-specific commands.
3. Only use an explicit local command table when no built-in pattern matches the CLI syntax.
4. Re-check upstream before keeping an old custom entry; if upstream later adds the tool, remove the redundant local entry unless an override is still required.

Known built-in patterns include `standard`, `completions`, `gh_style`, `generate_shell`, `gen_completions`, `completions_flag`, `argcomplete`, and `generate_complete`. Verify the current upstream registry before relying on this list.

Current repository custom entries are intentionally minimal: `codex`, `dasel`, `gup`, `herdr`, and `witr` use `standard`; `sheldon` and `topgrade` use explicit zsh commands because their CLI syntax does not match the existing patterns. Examples already covered upstream include `doggo`, `gh`, `uv`, and `atuin`.

## Editing discipline

- Make the smallest change that satisfies the request.
- Preserve the repository's current TOML/YAML/shell/PowerShell style unless a broader refactor is explicitly requested.
- Avoid duplicating package or tool declarations across generic and conditional configs.
- Do not move distro/package-manager logic into scripts merely for convenience.
- Do not broaden environment detection without checking how the new condition interacts with existing Ubuntu/Debian, Fedora/RHEL, Arch, Flatpak, WSL, and WSLg selection.
- When changing plugin order, reason about `fpath`, `compinit`, widget wrapping, and syntax-highlighting order before editing.
- When changing bootstrap actions, distinguish validation/dry-run behavior from actions that mutate the host system, login shell, package repositories, user services, credentials, Windows packages, or Windows Terminal settings.
- When changing update behavior, distinguish mise-managed tool/runtime upgrades from Topgrade-managed plugin/data/system steps so the same ecosystem is not upgraded twice.
- When adding a mise-managed CLI that can generate completions, also decide whether `mise-completions-sync` already supports it upstream, can use a built-in pattern in the local registry, or genuinely requires an explicit command.

## Validation

Before declaring a code/config change complete, read [references/validation.md](references/validation.md) and run the smallest relevant checks.

At minimum run syntax/static checks for changed files, `mise tasks validate --errors-only` for task/config changes, `mise --locked bootstrap --dry-run` for bootstrap/config changes when available, and the relevant `MISE_ENV` selection checks for `miserc.toml`/`conf.d` changes. Do not run the full real bootstrap on the user's machine merely as a test unless explicitly requested.

## Git operations

- Never discard, reset, or overwrite unrelated working-tree changes.
- Never force-push `master`.
- Follow the user's requested branch strategy.
- Commit only files belonging to the requested change.
- Before push/merge, re-check the diff and relevant validation results.
- When asked to merge a PR, inspect unresolved review feedback and CI state first unless the user explicitly tells you to bypass that review.

## Completion report

For implementation work, report what changed and why, files changed, validation results, commit/branch/PR information, and any remaining risk. Keep the report concise unless the user asks for detail.
