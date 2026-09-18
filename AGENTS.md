# AGENTS.md

Repository-wide instructions for coding agents working on this dotfiles repository.

## Start here

1. Read `spec.md` for the stable repository contract.
2. Read `.agents/skills/elliot-dotfiles/SKILL.md` for detailed routing, architecture, and validation guidance.
3. Inspect the current files that own the requested behavior before editing; documentation is guidance, not a substitute for the current repository state.
4. Preserve unrelated user changes.

Explicit user instructions take precedence. If a request intentionally changes the architecture, update `spec.md` in the same change.

## Working rules

- Make the smallest coherent change that satisfies the request.
- Prefer declarative mise configuration over new scripts.
- Keep generic, distro-specific, package-manager-specific, and platform-specific behavior in their existing ownership layers.
- Do not introduce a second synchronization or update mechanism that competes with mise history/sync or Topgrade.
- Do not hand-edit generated `config/mise.lock`.
- Keep `README.md` user-facing. Do not put maintainer architecture, migration internals, or implementation diaries there.
- Update README only when a user-facing command, prerequisite, limitation, or behavior changes.
- Prefer `nvim` in editor commands and examples; do not use `nano`.
- Do not discard, reset, overwrite, or reformat unrelated changes.

## Documentation maintenance

Keep documentation aligned with the layer it describes:

- Update `README.md` only when user-visible installation, commands, prerequisites, limitations, recovery steps, or behavior change.
- Update `spec.md` when the stable repository contract, architecture, or invariants intentionally change.
- Update `AGENTS.md` when repository-wide agent workflow, mandatory working rules, review policy, or documentation responsibilities change.
- Update `.agents/skills/elliot-dotfiles/SKILL.md` or its references when detailed maintenance guidance, ownership/routing, repository-specific procedures, or validation guidance change.
- Do not update documentation merely because implementation details changed when the contract described by that document remains accurate.

## Validation

Use the validation guidance in `.agents/skills/elliot-dotfiles/references/validation.md`.

Run the smallest relevant checks first. For shared mise/bootstrap/config changes, validate task/config parsing and the locked bootstrap dry-run where applicable. Do not run a real host-mutating bootstrap merely as a test unless explicitly requested.

When changing environment selection, setup/history behavior, or cross-platform bootstrap behavior, extend or run the corresponding CI coverage instead of relying on a single local environment.

## Pull requests

- Keep each PR scoped to the requested change.
- Re-check the diff before push or merge.
- Do not merge while CI is pending or failing.
- Wait for Codex review to cover the current PR head before merging.
- Resolve actionable Codex feedback, update the branch, then wait for CI and Codex review again on the new head.
- A PR is ready to merge only when CI is green and the current head has no unresolved actionable Codex feedback.

## Code Review Rules

Flag changes that:

- duplicate ownership of tools, packages, synchronization, updates, themes, or platform setup;
- move conditional behavior into the generic configuration without a cross-platform reason;
- add imperative scripts where existing mise configuration can represent the behavior safely;
- expand README with internal implementation details instead of user-operational information;
- hand-edit generated lock state;
- bypass relevant validation for bootstrap, environment-selection, or setup-history changes.
