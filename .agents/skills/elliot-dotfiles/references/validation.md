# Validation guide

Use targeted checks first, then broader checks when the change affects shared bootstrap/config behavior.

## Static checks

The repository's `hk.pkl` defines shell syntax/static validation.

When dependencies are available:

```sh
mise install --locked hk shellcheck
mise exec hk shellcheck -- hk check --all
```

Targeted fallbacks:

```sh
sh -n scripts/*.sh
zsh -n .zshrc .p10k.zsh
```

Run only commands that are valid for the files present in the current checkout.

### PowerShell

`hk.pkl` does not currently validate `scripts/bootstrap-windows.ps1`. When that file changes, parse it without executing WinGet or Windows Terminal mutations.

With PowerShell 7:

```sh
pwsh -NoLogo -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile("scripts/bootstrap-windows.ps1", [ref]$tokens, [ref]$errors) | Out-Null; if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }'
```

From WSL with Windows PowerShell, convert the path before parsing:

```sh
script="$(wslpath -w scripts/bootstrap-windows.ps1)"
powershell.exe -NoLogo -NoProfile -Command '$path=$args[0]; $tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null; if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }' "$script"
```

Do not use the real Windows bootstrap as a syntax test because it can install packages and rewrite Windows Terminal settings.

## mise validation

For changes to `config.toml`, `miserc.toml`, `conf.d/`, tasks, hooks, bootstrap, or lock-sensitive configuration:

```sh
mise tasks validate --errors-only
mise --locked bootstrap --dry-run
```

The dry-run is preferred for validation because a real bootstrap can mutate packages, repositories, dotfiles, login-shell settings, systemd units, credentials, Windows packages, or Windows Terminal settings.

When changing `tasks.bootstrap`, account for its current coordinated steps: completion installation/sync, Sheldon lock generation, Yazi package installation, hk setup, Nerd Font update, Windows bootstrap dispatch, and GitHub login. A dry-run validates task/config structure but does not prove every external program or platform-specific mutation will succeed.

## Environment selection

When changing `miserc.toml`, `conf.d/`, or environment naming, verify the selected configs.

The CI currently expects these relationships:

| `MISE_ENV` | Expected conditional config |
| --- | --- |
| `ubuntu,apt` | `conf.d/distro.ubuntu.toml`, `conf.d/packages.apt.toml` |
| `debian,apt` | `conf.d/packages.apt.toml` |
| `fedora,dnf` | `conf.d/distro.fedora.toml`, `conf.d/packages.dnf.toml` |
| `rhel,dnf` | `conf.d/packages.dnf.toml` |
| `arch,pacman` | `conf.d/packages.pacman.toml` |
| `flatpak` | `config.flatpak.toml` |

A useful manual pattern is:

```sh
MISE_ENV='ubuntu,apt' MISE_ENV_CONF_D=true mise config ls
```

Change the environment list for the path being tested and confirm the expected files are loaded.

For WSL-specific changes, also inspect `conf.d/platform.wsl.toml` and confirm the Windows bootstrap is only dispatched when the `wsl` environment is selected and `powershell.exe` is available.

If selection behavior changes intentionally, update `.github/workflows/ci.yml` so CI encodes the new architecture.

## Tool or lockfile changes

- Never edit `mise.lock` by hand.
- Use the appropriate mise command to regenerate lock state only when the requested tool/config change requires it.
- Review the lockfile diff and avoid accepting unrelated mass version churn unless the task is explicitly an update.
- If the request is only to change documentation or shell behavior that does not affect mise tool resolution, do not refresh the lockfile.

## Sheldon/Zsh changes

For `.config/sheldon/plugins.toml`, check ordering as well as syntax:

1. completion directories before `compinit`;
2. integrations that depend on completion initialization after `compinit`;
3. `fzf-tab` before plugins that wrap completion widgets;
4. syntax highlighting last among plugins.

If plugin lock/update commands are run, inspect generated changes and keep unrelated plugin upgrades out of narrowly scoped changes.

## Completion registry changes

For `.local/share/mise-completions-sync/registry.toml`:

1. compare the local entry with the current upstream built-in registry;
2. prefer a built-in pattern over an explicit shell command when the CLI syntax matches;
3. validate the generated command shape against the target CLI;
4. when available, use `misecompsync list` or a targeted `misecompsync <tool> --shell zsh` run rather than relying only on TOML parsing.

Do not run a broad completion refresh merely to validate one registry mapping if it would rewrite unrelated generated completions.

## Yazi changes

For `.config/yazi/` changes:

- keep plugin dependency declarations in `package.toml`;
- inspect `keymap.toml`, `init.lua`, and `yazi.toml` when a plugin also requires bindings or initialization;
- prefer Yazi's own package inspection/sync commands supported by the installed version;
- avoid deleting or re-resolving unrelated plugin state during a narrowly scoped change;
- remember that the real bootstrap runs `ya pkg install`, so modifying the manifest changes bootstrap behavior.

## Topgrade and update changes

Topgrade is the current user-session update orchestrator.

When editing `.config/topgrade.toml`, `.config/topgrade.systemd.toml`, or the `update` systemd units:

- confirm mise-managed ecosystems remain disabled where intended so updates are not duplicated;
- distinguish interactive Topgrade behavior from unattended systemd behavior;
- verify custom commands such as Nerd Font update and completion refresh still point to valid mise tasks/commands;
- use Topgrade dry-run or configuration inspection when available before running a real update.

Do not use a real full Topgrade run as a routine validation step because it can update many unrelated tools, plugins, packages, or data sets.

## Nerd Font changes

For `scripts/update-fonts.sh` or `tasks.update:fonts` changes:

- run shell syntax/static checks;
- preserve WSL skip behavior unless the design is intentionally changing;
- preserve checksum verification when downloading Nerd Fonts;
- avoid running a real font update merely to validate control flow unless the user explicitly requests it.

Windows font behavior belongs to `scripts/bootstrap-windows.ps1` and should be validated through the PowerShell path above.

## Documentation changes

When installation, bootstrap, update, add/remove-tool, Yazi plugin, Windows bootstrap, font maintenance, or dotfile management behavior changes, verify that `README.md` examples still match the implemented commands.

## Before push or merge

1. Inspect `git diff` / PR diff.
2. Confirm no unrelated files or generated churn slipped in.
3. Run relevant static checks.
4. Run mise task/bootstrap validation for configuration changes.
5. Confirm CI environment-selection coverage if conditional loading changed.
6. Run a PowerShell parser check when `scripts/bootstrap-windows.ps1` changed.
7. Report any check that could not be run.
