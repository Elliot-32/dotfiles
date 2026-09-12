# Validation guide

Use targeted checks first, then broader checks when the change affects shared bootstrap/config behavior.

## Static checks

Run hk from the portable config root so it reads `config/hk.pkl` while its Zsh checks reach the native setup files under `../home/`:

```sh
cd config
mise install --locked hk shellcheck
mise exec hk shellcheck -- hk check --all
```

Targeted fallbacks from the repository root:

```sh
sh -n config/scripts/*.sh
zsh -n home/.zshrc home/.p10k.zsh
```

### PowerShell

Parse `config/scripts/bootstrap-windows.ps1` without executing WinGet:

```sh
pwsh -NoLogo -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile("config/scripts/bootstrap-windows.ps1", [ref]$tokens, [ref]$errors) | Out-Null; if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }'
```

## mise validation

For a repository checkout, point mise at the portable config root rather than assuming the checkout itself is `$MISE_CONFIG_DIR`:

```sh
MISE_CONFIG_DIR="$PWD/config" MISE_TRUSTED_CONFIG_PATHS="$PWD/config" mise tasks validate --errors-only
MISE_CONFIG_DIR="$PWD/config" MISE_TRUSTED_CONFIG_PATHS="$PWD/config" mise --locked bootstrap --dry-run
```

A real bootstrap can mutate packages, login-shell settings, systemd units, credentials, and the Windows font installation. Tinty apply/init can additionally mutate Windows Terminal settings on WSL, so prefer dry-run and targeted tests for validation.

## Setup/history validation

When tracking, setup layout, or sync behavior changes, verify `.mise-history/manifest.json` matches the portable roots and that a fresh user can onboard from the setup repository. Native tracked files should resolve under `$HOME`; portable `config/*` entries must resolve against the active `MISE_CONFIG_DIR`, including a non-default one. Do not accept a test that merely checks the default `~/.config/mise` path.

For direct-tracked files such as `~/.zshrc`, verify the restored path is a regular native file rather than a symlink to `$MISE_CONFIG_DIR`. Declarative exceptions such as the APT/Fcitx5 files may still use deployment modes intentionally.

## Environment selection

When changing `home/.miserc.toml`, `config/conf.d/`, or environment naming, verify expected config selection. Current relationships include Ubuntu/APT, Debian/APT, Fedora/DNF, RHEL/DNF, Arch/Pacman, Flatpak, WSL, and WSLg. CI should be updated whenever this architecture changes.

## Tool or lockfile changes

- Never edit `config/mise.lock` by hand.
- Regenerate lock state only when the requested tool/config change requires it.
- Review lockfile churn and avoid unrelated mass updates.

## Sheldon/Zsh, Yazi, completions, and Topgrade

Use native setup paths when reviewing these files:

- `home/.config/sheldon/plugins.toml` and `home/.zshrc` for shell/plugin ordering;
- `home/.config/yazi/` for Yazi plugin declarations, bindings, and initialization;
- `home/.local/share/mise-completions-sync/registry.toml` for local completion mappings;
- `home/.config/topgrade.toml` and `home/.config/topgrade.systemd.toml` for update behavior.

Keep upstream-native package/plugin mechanisms where available and avoid a second updater or sync path that competes with mise.

## Before push or merge

1. Inspect the PR diff.
2. Confirm no duplicate source tree or generated churn slipped in.
3. Run relevant static checks.
4. Run mise task/bootstrap dry-run validation against `config/`.
5. For setup changes, run fresh-machine onboarding validation with a non-default `MISE_CONFIG_DIR`.
6. Confirm CI and unresolved review state.
