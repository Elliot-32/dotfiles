#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys

DEFAULT_SCHEME = "base24-catppuccin-macchiato"


def config_dir() -> Path:
    return Path(os.environ.get("MISE_CONFIG_DIR", Path.home() / ".config/mise")).expanduser()


def state_root() -> Path:
    base = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")).expanduser()
    return base / "dotfiles/theme"


def tinty_config_path() -> Path:
    return state_root() / "tinty.toml"


def tinty_templates_root() -> Path:
    return state_root() / "tinty-templates"


def run(
    command: list[str],
    *,
    capture: bool = False,
    check: bool = True,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        check=check,
        text=True,
        input=input_text,
        stdout=subprocess.PIPE if capture else None,
    )


def tinty(*args: str, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return run(
        ["tinty", *args, "--config", str(tinty_config_path())],
        capture=capture,
    )


def toml_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def hook_command(*parts: str) -> str:
    return " ".join(shlex.quote(part) for part in parts)


def write_tinty_config() -> None:
    root = state_root()
    root.mkdir(parents=True, exist_ok=True)

    script = config_dir() / "scripts/theme.py"
    template_root = tinty_templates_root()

    finalize_hook = hook_command("python3", str(script), "finalize")
    gomi_hook = (
        hook_command("python3", str(script), "apply-gomi")
        + ' "$TINTY_THEME_FILE_PATH" "$TINTY_SCHEME_SLUG"'
    )
    windows_hook = (
        hook_command("python3", str(script), "apply-windows-terminal")
        + ' "$TINTY_THEME_FILE_PATH"'
    )

    content = "\n".join(
        [
            'shell = "sh -c \'{}\'"',
            f"default-scheme = {toml_string(DEFAULT_SCHEME)}",
            f"hooks = [{toml_string(finalize_hook)}]",
            "",
            "[[items]]",
            f"path = {toml_string(str(template_root / 'gomi'))}",
            'name = "gomi"',
            'themes-dir = "themes"',
            'supported-systems = ["base24"]',
            f"hook = {toml_string(gomi_hook)}",
            "",
            "[[items]]",
            f"path = {toml_string(str(template_root / 'windows-terminal'))}",
            'name = "windows-terminal"',
            'themes-dir = "themes"',
            'supported-systems = ["base24"]',
            f"hook = {toml_string(windows_hook)}",
            "",
        ]
    )
    tinty_config_path().write_text(content, encoding="utf-8")


def copy_template_repositories() -> None:
    source_root = config_dir() / "assets/theme"
    destination_root = tinty_templates_root()
    destination_root.mkdir(parents=True, exist_ok=True)

    for name in ("gomi", "windows-terminal"):
        source = source_root / name
        destination = destination_root / name
        if not source.is_dir():
            raise RuntimeError(f"theme template repository is missing: {source}")
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(source, destination)


def build_templates() -> None:
    for name in ("gomi", "windows-terminal"):
        tinty("build", str(tinty_templates_root() / name), "--quiet")


def prepare(*, sync: bool) -> None:
    copy_template_repositories()
    write_tinty_config()

    if sync:
        tinty("sync", "--quiet")
        build_templates()
        return

    try:
        build_templates()
    except subprocess.CalledProcessError:
        tinty("sync", "--quiet")
        build_templates()


def base24_schemes() -> list[str]:
    output = tinty("list", "--json", capture=True).stdout or "[]"
    entries = json.loads(output)
    schemes = [
        str(entry["id"])
        for entry in entries
        if str(entry.get("system", "")) == "base24"
        and str(entry.get("id", "")).startswith("base24-")
    ]
    return sorted(schemes)


def choose_scheme() -> str:
    if shutil.which("gum") is None:
        raise RuntimeError("gum is required for interactive theme selection")

    schemes = base24_schemes()
    if not schemes:
        raise RuntimeError("Tinty did not return any Base24 schemes")

    result = run(
        [
            "gum",
            "filter",
            "--header",
            "Choose a Base24 theme",
            "--placeholder",
            "Search themes...",
        ],
        capture=True,
        check=False,
        input_text="\n".join(schemes) + "\n",
    )
    if result.returncode != 0:
        raise RuntimeError("theme selection was cancelled")

    selected = (result.stdout or "").strip()
    if selected not in schemes:
        raise RuntimeError("gum returned an unknown theme")
    return selected


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(content, encoding="utf-8")
    os.replace(temporary, path)


def current_scheme_name() -> str:
    result = tinty("current", "name", capture=True)
    name = (result.stdout or "").strip()
    if not name:
        raise RuntimeError("Tinty did not report the current scheme name")
    return name


def current_scheme_slug() -> str:
    slug = os.environ.get("TINTY_SCHEME_SLUG", "").strip()
    if slug:
        return slug
    result = tinty("current", "slug", capture=True)
    slug = (result.stdout or "").strip()
    if not slug:
        raise RuntimeError("Tinty did not report the current scheme slug")
    return slug


def ghostty_theme_name(name: str, slug: str) -> str:
    aliases = {
        "catppuccin-frappe": "Catppuccin Frappe",
        "catppuccin-latte": "Catppuccin Latte",
        "catppuccin-macchiato": "Catppuccin Macchiato",
        "catppuccin-mocha": "Catppuccin Mocha",
        "dracula": "Dracula",
        "tokyo-night-dark": "TokyoNight",
        "tokyo-night": "TokyoNight",
    }
    return aliases.get(slug, name)


def write_ghostty_runtime() -> None:
    name = current_scheme_name()
    slug = current_scheme_slug()
    theme = ghostty_theme_name(name, slug)
    atomic_write(state_root() / "ghostty.conf", f"theme = {theme}\n")


_YAML_KEY = re.compile(r"^(\s*)([A-Za-z0-9_]+):(?:\s*(.*?))?(\r?\n)?$")


def yaml_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def patch_yaml_mapping(text: str, replacements: dict[tuple[str, ...], str]) -> str:
    stack: list[tuple[int, str]] = []
    output: list[str] = []

    for line in text.splitlines(keepends=True):
        match = _YAML_KEY.match(line)
        if match is None:
            output.append(line)
            continue

        indent_text, key, raw_value, newline = match.groups()
        indent = len(indent_text)
        raw_value = raw_value or ""

        while stack and stack[-1][0] >= indent:
            stack.pop()

        path = tuple(item[1] for item in stack) + (key,)
        if path in replacements:
            output.append(
                f"{indent_text}{key}: {yaml_quote(replacements[path])}{newline or ''}"
            )
        else:
            output.append(line)

        if raw_value.strip() == "":
            stack.append((indent, key))

    return "".join(output)


def gomi_colorscheme(slug: str) -> str | None:
    aliases = {
        "catppuccin-latte": "catppuccin-latte",
        "catppuccin-mocha": "catppuccin-mocha",
        "dracula": "dracula",
        "gruvbox-dark-hard": "gruvbox",
        "gruvbox-dark-medium": "gruvbox",
        "gruvbox-dark-pale": "gruvbox",
        "gruvbox-dark-soft": "gruvbox",
        "gruvbox-light-hard": "gruvbox-light",
        "gruvbox-light-medium": "gruvbox-light",
        "gruvbox-light-soft": "gruvbox-light",
        "nord": "nord",
        "rose-pine": "rose-pine",
        "rose-pine-dawn": "rose-pine-dawn",
        "rose-pine-moon": "rose-pine-moon",
        "solarized-dark": "solarized-dark",
        "solarized-light": "solarized-light",
        "tokyo-night-dark": "tokyonight-night",
        "tokyo-night-light": "tokyonight-day",
        "tokyo-night-moon": "tokyonight-moon",
        "tokyo-night-storm": "tokyonight-storm",
    }
    return aliases.get(slug)


def apply_gomi(theme_file: Path, slug: str) -> None:
    data = json.loads(theme_file.read_text(encoding="utf-8"))
    colors = data["colors"]

    base = config_dir() / "assets/gomi/config.yaml"
    text = base.read_text(encoding="utf-8")

    replacements: dict[tuple[str, ...], str] = {
        ("ui", "style", "list_view", "cursor"): colors["cursor"],
        ("ui", "style", "list_view", "selected"): colors["selected"],
        ("ui", "style", "list_view", "filter_match"): colors["filter_match"],
        ("ui", "style", "list_view", "filter_prompt"): colors["filter_prompt"],
        ("ui", "style", "detail_view", "border"): colors["detail_border"],
        ("ui", "style", "detail_view", "info_pane", "deleted_from", "fg"): colors["pane_fg"],
        ("ui", "style", "detail_view", "info_pane", "deleted_from", "bg"): colors["pane_bg"],
        ("ui", "style", "detail_view", "info_pane", "deleted_at", "fg"): colors["pane_fg"],
        ("ui", "style", "detail_view", "info_pane", "deleted_at", "bg"): colors["pane_bg"],
        ("ui", "style", "detail_view", "preview_pane", "border"): colors["preview_border"],
        ("ui", "style", "detail_view", "preview_pane", "size", "fg"): colors["preview_fg"],
        ("ui", "style", "detail_view", "preview_pane", "size", "bg"): colors["preview_bg"],
        ("ui", "style", "detail_view", "preview_pane", "scroll", "fg"): colors["preview_fg"],
        ("ui", "style", "detail_view", "preview_pane", "scroll", "bg"): colors["preview_bg"],
        ("ui", "style", "deletion_dialog"): colors["danger"],
    }

    colorscheme = gomi_colorscheme(slug)
    if colorscheme is not None:
        replacements[("ui", "preview", "colorscheme")] = colorscheme

    rendered = patch_yaml_mapping(text, replacements)
    atomic_write(state_root() / "gomi.yaml", rendered)


def is_wsl() -> bool:
    return bool(
        os.environ.get("WSL_DISTRO_NAME")
        or os.environ.get("WSL_INTEROP")
        or Path("/proc/sys/fs/binfmt_misc/WSLInterop").exists()
    )


def apply_windows_terminal(theme_file: Path) -> None:
    if not is_wsl():
        return
    if shutil.which("powershell.exe") is None or shutil.which("wslpath") is None:
        print(
            "warning: WSL detected but powershell.exe or wslpath is unavailable; "
            "skipping Windows Terminal theme",
            file=sys.stderr,
        )
        return

    script = config_dir() / "scripts/theme-windows-terminal.ps1"
    windows_script = run(["wslpath", "-w", str(script)], capture=True).stdout.strip()
    windows_theme = run(["wslpath", "-w", str(theme_file)], capture=True).stdout.strip()

    run(
        [
            "powershell.exe",
            "-NoLogo",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            windows_script,
            "-ThemeFile",
            windows_theme,
        ]
    )


def apply_omarchy_gomi_if_available() -> None:
    if shutil.which("omarchy") is None:
        return
    state_theme = (
        Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
        / "omarchy/current/theme"
    )
    if not state_theme.is_dir():
        return

    result = run(["omarchy", "theme", "current"], capture=True, check=False)
    if result.returncode != 0:
        return

    theme = (result.stdout or "").strip()
    if not theme:
        return

    hook = config_dir() / "scripts/omarchy-gomi-theme-sync.sh"
    run(["bash", str(hook), theme])


def finalize() -> None:
    write_ghostty_runtime()
    apply_omarchy_gomi_if_available()


def command_init() -> None:
    prepare(sync=True)
    tinty("init")


def command_choose() -> None:
    prepare(sync=False)
    selected = choose_scheme()
    tinty("apply", selected)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Apply dotfiles themes with Tinty")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("init")
    subparsers.add_parser("choose")
    subparsers.add_parser("finalize")

    gomi_parser = subparsers.add_parser("apply-gomi")
    gomi_parser.add_argument("theme_file", type=Path)
    gomi_parser.add_argument("slug")

    windows_parser = subparsers.add_parser("apply-windows-terminal")
    windows_parser.add_argument("theme_file", type=Path)

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.command == "init":
            command_init()
        elif args.command == "choose":
            command_choose()
        elif args.command == "finalize":
            finalize()
        elif args.command == "apply-gomi":
            apply_gomi(args.theme_file, args.slug)
        elif args.command == "apply-windows-terminal":
            apply_windows_terminal(args.theme_file)
        else:
            raise RuntimeError(f"unsupported command: {args.command}")
    except (OSError, RuntimeError, subprocess.CalledProcessError, KeyError, ValueError) as error:
        print(f"theme: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
