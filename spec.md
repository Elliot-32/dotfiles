# dotfiles specification

This document defines the stable repository contract. Implementation details may move; these invariants should remain true unless a change intentionally updates the design.

## Purpose

This repository provides a portable personal environment managed by mise across Linux and WSL, with conditional behavior for distro/package-manager/platform differences.

The repository should keep one coherent configuration model rather than separate per-machine copies.

## Core invariants

- mise is the primary tool, package, bootstrap, task, and dotfile orchestration layer.
- `config/` is the portable representation of the active `MISE_CONFIG_DIR`.
- `home/` is the portable representation of files restored under `$HOME`.
- `home/.miserc.toml` selects named environments; conditional configuration belongs in `config/conf.d/`.
- Generic behavior belongs in `config/config.toml`; distro, package-manager, and platform differences stay isolated in their matching conditional fragments.
- Prefer declarative mise configuration. Use scripts only for inherently imperative, interactive, or platform-native work.
- Ordinary user configuration should be tracked at the native path applications read instead of introducing an extra symlink source tree.
- mise history/sync is the authority for synchronized configuration state. Do not add a competing Git-based sync mechanism.
- `config/mise.lock` is generated state and must not be edited by hand.
- Keep unrelated machine-local state, credentials, and identity outside synchronized configuration.

## Environment model

The configuration may select combinations of environments for:

- APT-based systems;
- DNF-based systems;
- Pacman/Arch systems;
- Flatpak-capable graphical systems;
- WSL and WSLg;
- Omarchy;
- the explicit `laptop` profile.

Platform-specific behavior must not leak into generic environments unless it is valid everywhere.

## User-visible behavior

- `mise bootstrap` is the canonical setup/reconciliation path.
- `update` is the user-facing update entry point; Topgrade coordinates normal update work.
- Non-Omarchy environments use Tinty for theme selection and application.
- Omarchy uses its native theme system instead of routing theme changes through Tinty.
- WSL may integrate with Windows for font and Windows Terminal behavior while keeping Linux configuration authoritative.
- The `laptop` profile is opt-in. It requires `keyd` and owns only the explicitly requested system-wide keyboard remap.

## Documentation boundaries

- `README.md` contains only information a user needs to install, operate, or recover the setup.
- `AGENTS.md` contains repository-wide working rules for coding agents.
- `.agents/skills/elliot-dotfiles/SKILL.md` contains detailed maintenance guidance, routing rules, and validation procedures.
- Maintainer architecture details should live in the skill or its references rather than expanding the README.

## Change requirements

Changes should:

- preserve existing behavior outside the requested scope;
- avoid duplicate ownership of tools, packages, updates, themes, or synchronization;
- keep platform-specific logic conditional;
- update user documentation when a user-facing command, prerequisite, or behavior changes;
- add or update validation when an architectural invariant or environment-selection rule changes.

A change is complete only when relevant validation passes and the resulting repository still satisfies the invariants above.
