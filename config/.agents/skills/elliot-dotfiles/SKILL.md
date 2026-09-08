---
name: elliot-dotfiles
description: Maintain, review, and evolve Elliot-32/dotfiles, a mise-centric Linux/WSL dotfiles repository. Use for work involving config.toml, miserc.toml, conf.d environment selection, mise tools/bootstrap/tasks, package managers, Flatpak, Zsh/Sheldon plugins and completions, Yazi, Topgrade, Ghostty, Nerd Fonts, WSL/WSLg and Windows bootstrap, hk/CI, mise.lock, README updates, or repository refactors.
license: MIT
compatibility: Intended for Agent Skills-compatible coding agents working in a checkout of Elliot-32/dotfiles. Validation assumes git and mise; some checks additionally use zsh, hk, shellcheck, and PowerShell.
metadata:
  author: Elliot-32
  version: "1.2"
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

- Treat `config.toml` as the main mise global configuration. Keep generic settings, environment variables, tool declarations, dotfile mappings, bootstrap definitions, systemd units, tasks, and hooks there unless they are conditional.
- Treat `miserc.toml` as the environment selector. It detects distro/package-manager/platform capabilities and selects named mise environments.
- Route conditional configuration through `conf.d/`:
  - `distro.*.toml`: distro-specific repository/bootstrap behavior.
  - `packages.*.toml`: package-manager-specific packages/settings.
  - `platform.*.toml`: platform behavior such as WSL/WSLg.
- Keep Flatpak-specific configuration in `config.flatpak.toml`.
- Prefer declarative mise configuration over shell scripts. Add or extend a script only when the operation is inherently imperative, interactive, platform-native, or cannot be represented safely in mise configuration.
- Dotfiles are deployed by mise and default to symlinks. Add managed files through `[dotfiles]`; do not introduce a second dotfile manager.
- Treat Topgrade as the user-session update orchestrator. Its configs deliberately disable runtimes/package ecosystems already managed by mise while retaining update steps for plugin/data refreshes, Nerd Fonts, and generated completions. Do not recreate a competing generic mise update task without checking the current Topgrade path first.
- Treat `.config/yazi/package.toml` as Yazi's plugin manifest. Bootstrap installs declared plugins with `ya pkg install`; change plugin declarations there rather than adding ad-hoc plugin install commands elsewhere.
- Treat `conf.d/platform.wsl.toml` plus `scripts/bootstrap-windows.ps1` as the WSL-to-Windows bootstrap path. Keep Windows-native WinGet/package/Windows Terminal behavior in PowerShell instead of moving it into Linux package configuration.
- Linux Nerd Font maintenance is owned by `tasks.update:fonts` and `scripts/update-fonts.sh`; Windows font installation is owned by `scripts/bootstrap-windows.ps1`. Preserve the intentional WSL split.
- Keep Zsh plugin and completion ordering in `.config/sheldon/plugins.toml` deliberate:
  1. completion directories on `fpath`,
  2. `compinit`,
  3. integrations that require completion initialization,
  4. `fzf-tab` before widget-wrapping plugins,
  5. syntax highlighting last among plugins.
- Prefer `nvim` for editor commands and examples; do not introduce `nano`.
- If a user-visible command, bootstrap behavior, installation flow, or maintenance workflow changes, update `README.md` in the same change.
- Treat `mise.lock` as generated state. Never hand-edit it. Only refresh it when the requested change requires lockfile changes, and review the diff for unrelated churn.

## Route common changes

Use [references/repository-map.md](references/repository-map.md) for details. In general:

- Add or remove a mise-managed CLI/tool: edit `[tools]` in `config.toml`.
- Add a distro package: edit the matching `conf.d/packages.<manager>.toml`.
- Add a distro-only repository or bootstrap prerequisite: edit the matching `conf.d/distro.<distro>.toml`.
- Add a Flatpak app/remote/bootstrap change: edit `config.flatpak.toml` and its existing bootstrap path.
- Change distro/platform detection: edit `miserc.toml`, then extend CI selection checks.
- Change Zsh plugin loading, `fpath`, completion, widgets, or zstyle setup: inspect `.config/sheldon/plugins.toml` and `.zshrc`; place behavior in the layer that owns it rather than duplicating initialization.
- Change generated CLI completions: inspect `config.toml` hooks/tasks, `.local/share/mise-completions-sync/registry.toml`, and the current upstream `mise-completions-sync` registry before editing.
- Change shell startup environment: inspect `.zshenv`, `.zprofile`, `.zshrc`, Sheldon config, and mise shell activation before adding another initialization path.
- Add, remove, or configure a Yazi plugin: inspect `.config/yazi/package.toml`, `.config/yazi/init.lua`, `.config/yazi/keymap.toml`, and `.config/yazi/yazi.toml`; keep plugin installation delegated to the existing `ya pkg install` bootstrap step.
- Change unattended/user-session update behavior: inspect `.config/topgrade.toml`, `.config/topgrade.systemd.toml`, and the `update` / `update-timer` systemd units in `config.toml` before adding another updater.
- Change Linux Nerd Font installation/update behavior: edit `scripts/update-fonts.sh` and the `update:fonts` task path in `config.toml`; preserve checksum verification and WSL skip behavior unless the change explicitly replaces that design.
- Change Windows packages, Windows Terminal defaults, or other WSL-triggered Windows setup: inspect `conf.d/platform.wsl.toml`, `tasks.bootstrap:windows`, and `scripts/bootstrap-windows.ps1`.
- Change bootstrap behavior: prefer existing `[bootstrap.*]`, `[tasks.*]`, and `[hooks]` in `config.toml`, including the existing completion sync, Sheldon lock, Yazi package install, hk setup, font update, Windows bootstrap, and GitHub login flow.
- Change validation/pre-commit checks: edit `hk.pkl` and, when necessary, `.github/workflows/ci.yml`.

## Completion registry rules

This repository uses `mise-completions-sync` for mise-managed CLI completions. The local overlay is `.local/share/mise-completions-sync/registry.toml`; it is deployed through `[dotfiles]` in `config.toml`. Bootstrap runs `misecompsync --shell zsh`, and the post-install hook runs `misecompsync --new-only --shell zsh`.

When adding or changing completion support for a tool, use this priority order:

1. Check whether the tool already exists in the current upstream `mise-completions-sync` built-in registry. If it does, do not add a local entry unless the repository intentionally needs an override.
2. If the tool is not built in, check whether its completion command matches one of the built-in patterns. Prefer a short pattern entry such as `tool = "standard"` instead of duplicating shell-specific commands.
3. Only use an explicit local command table when no built-in pattern matches the CLI syntax.
4. Re-check upstream before keeping an old custom entry; if upstream later adds the tool, remove the redundant local entry unless an override is still required.

Known built-in patterns include:

- `standard`: `{} completion <shell>`
- `completions`: `{} completions <shell>`
- `gh_style`: `{} completion -s <shell>`
- `generate_shell`: `{} generate-shell-completion <shell>`
- `gen_completions`: `{} gen-completions --shell <shell>`
- `completions_flag`: `{} --completions <shell>`
- `argcomplete`: `register-python-argcomplete -s <shell> {}`
- `generate_complete`: shell-specific `{} --generate=complete-<shell>` forms

Do not assume this list or upstream mappings are permanent; `mise-completions-sync` is version-sensitive, so verify the current upstream registry when making a completion change.

Current repository custom entries are intentionally minimal:

- `codex`, `dasel`, `gup`, `herdr`, and `witr` use the built-in `standard` pattern through the local overlay because they are not currently built into upstream.
- `sheldon` uses an explicit zsh command because its syntax is `sheldon completions --shell zsh`, which does not match the existing `completions` pattern.
- `topgrade` uses an explicit zsh command because its syntax is `topgrade --gen-completion zsh`, which does not match the existing patterns.

Examples of tools already covered by upstream and therefore not present in the local overlay include `doggo` via `completions`, `gh` via `gh_style`, `uv` via `generate_shell`, and `atuin` via `gen_completions`. When auditing the local registry, compare every local entry against upstream first rather than assuming a custom entry is still needed.

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

At minimum:

- run syntax/static checks for files you changed;
- run `mise tasks validate --errors-only` for task/config changes;
- run `mise --locked bootstrap --dry-run` for bootstrap/config changes when mise is available;
- validate the relevant `MISE_ENV` selection whenever `miserc.toml`, `conf.d/`, or Flatpak selection changes;
- for completion-registry changes, validate the generated command shape against the tool and, when available, use `misecompsync list` or a targeted `misecompsync <tool> --shell zsh` run rather than only checking TOML syntax;
- for Yazi plugin changes, validate `package.toml` and prefer a non-destructive Yazi package inspection/sync check when supported by the installed version; do not remove unrelated plugin state;
- for `scripts/bootstrap-windows.ps1`, run a PowerShell parser/syntax check without executing its WinGet or Windows Terminal mutations;
- do not run the full real bootstrap on the user's machine merely as a test unless explicitly requested.

If a required check cannot be run, state exactly which check was skipped and why.

## Git operations

- Never discard, reset, or overwrite unrelated working-tree changes.
- Never force-push `master`.
- Follow the user's requested branch strategy. If they explicitly ask for a new branch/PR, use one; if they explicitly ask for direct `master`, do not silently substitute a PR.
- Commit only files belonging to the requested change.
- Before push/merge, re-check the diff and relevant validation results.
- When asked to merge a PR, inspect unresolved review feedback and CI state first unless the user explicitly tells you to bypass that review.

## Completion report

For implementation work, report:

- what changed and why;
- files changed;
- validation run and results;
- commit/branch/PR/merge information when applicable;
- any remaining risk or intentionally skipped validation.

Keep the report concise unless the user asks for a detailed explanation.
