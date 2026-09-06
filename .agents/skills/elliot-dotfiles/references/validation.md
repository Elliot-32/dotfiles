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

## mise validation

For changes to `config.toml`, `miserc.toml`, `conf.d/`, tasks, hooks, bootstrap, or lock-sensitive configuration:

```sh
mise tasks validate --errors-only
mise --locked bootstrap --dry-run
```

The dry-run is preferred for validation because a real bootstrap can mutate packages, repositories, dotfiles, login-shell settings, systemd units, or credentials.

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

## Documentation changes

When installation, bootstrap, update, add/remove-tool, or dotfile management behavior changes, verify that `README.md` examples still match the implemented commands.

## Before push or merge

1. Inspect `git diff` / PR diff.
2. Confirm no unrelated files or generated churn slipped in.
3. Run relevant static checks.
4. Run mise task/bootstrap validation for configuration changes.
5. Confirm CI environment-selection coverage if conditional loading changed.
6. Report any check that could not be run.
