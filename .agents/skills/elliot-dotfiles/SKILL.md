---
name: elliot-dotfiles
description: Maintain, review, and evolve Elliot-32/dotfiles, a mise-centric Linux/WSL dotfiles repository. Use for work involving config.toml, miserc.toml, conf.d environment selection, mise tools/bootstrap/tasks, package managers, Flatpak, Zsh/Sheldon plugins and completions, Ghostty, WSL/WSLg, hk/CI, mise.lock, README updates, or repository refactors.
license: MIT
compatibility: Intended for Agent Skills-compatible coding agents working in a checkout of Elliot-32/dotfiles. Validation assumes git and mise; some checks additionally use zsh, hk, and shellcheck.
metadata:
  author: Elliot-32
  version: "1.0"
---

# Elliot dotfiles maintenance

Maintain this repository with minimal, architecture-consistent changes.

The user's explicit instructions take precedence over this skill. Do not turn a request for analysis into a repository mutation, and do not commit, push, open a PR, or merge unless the user asks for that action.

## Start every repository task

1. Inspect the current branch and working tree before editing.
2. Read the files that own the behavior being changed; do not rely only on this skill's repository snapshot.
3. Read [references/repository-map.md](references/repository-map.md) when the task crosses configuration layers or when file ownership is unclear.
4. Keep unrelated user changes intact.
5. For version-sensitive mise, shell-plugin, package-manager, or CI behavior, verify current upstream documentation when the answer depends on behavior not demonstrated by this repository.

## Architecture rules

- Treat `config.toml` as the main mise global configuration. Keep generic settings, environment variables, tool declarations, dotfile mappings, bootstrap definitions, systemd units, tasks, and hooks there unless they are conditional.
- Treat `miserc.toml` as the environment selector. It detects distro/package-manager/platform capabilities and selects named mise environments.
- Route conditional configuration through `conf.d/`:
  - `distro.*.toml`: distro-specific repository/bootstrap behavior.
  - `packages.*.toml`: package-manager-specific packages/settings.
  - `platform.*.toml`: platform behavior such as WSL/WSLg.
- Keep Flatpak-specific configuration in `config.flatpak.toml`.
- Prefer declarative mise configuration over shell scripts. Add or extend a script only when the operation is inherently imperative, interactive, or cannot be represented safely in mise configuration.
- Dotfiles are deployed by mise and default to symlinks. Add managed files through `[dotfiles]`; do not introduce a second dotfile manager.
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
- Change Zsh plugin loading, fpath, completion, widgets, or zstyle setup: inspect `.config/sheldon/plugins.toml` and `.zshrc`; place behavior in the layer that owns it rather than duplicating initialization.
- Change shell startup environment: inspect `.zshenv`, `.zprofile`, `.zshrc`, Sheldon config, and mise shell activation before adding another initialization path.
- Change bootstrap/update behavior: prefer existing `[bootstrap.*]`, `[tasks.*]`, and `[hooks]` in `config.toml`.
- Change validation/pre-commit checks: edit `hk.pkl` and, when necessary, `.github/workflows/ci.yml`.

## Editing discipline

- Make the smallest change that satisfies the request.
- Preserve the repository's current TOML/YAML/shell style unless a broader refactor is explicitly requested.
- Avoid duplicating package or tool declarations across generic and conditional configs.
- Do not move distro/package-manager logic into scripts merely for convenience.
- Do not broaden environment detection without checking how the new condition interacts with existing Ubuntu/Debian, Fedora/RHEL, Arch, Flatpak, WSL, and WSLg selection.
- When changing plugin order, reason about `fpath`, `compinit`, widget wrapping, and syntax-highlighting order before editing.
- When changing bootstrap actions, distinguish validation/dry-run behavior from actions that mutate the host system, login shell, package repositories, user services, or credentials.

## Validation

Before declaring a code/config change complete, read [references/validation.md](references/validation.md) and run the smallest relevant checks.

At minimum:

- run syntax/static checks for files you changed;
- run `mise tasks validate --errors-only` for task/config changes;
- run `mise --locked bootstrap --dry-run` for bootstrap/config changes when mise is available;
- validate the relevant `MISE_ENV` selection whenever `miserc.toml`, `conf.d/`, or Flatpak selection changes;
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
