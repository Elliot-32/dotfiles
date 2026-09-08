#!/usr/bin/env bash
set -euo pipefail

if [[ -n ${WSL_DISTRO_NAME:-} || -n ${WSL_INTEROP:-} || -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
  echo 'WSL detected; skipping Linux font installation.'
  exit 0
fi

for command in curl tar sha256sum fc-cache; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "error: required command '$command' is unavailable" >&2
    exit 1
  fi
done

font_root="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
font_dir="$font_root/JetBrainsMonoNerdFont"
version_file="$font_dir/.nerd-font-version"
latest_release='https://github.com/ryanoasis/nerd-fonts/releases/latest'

latest_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "$latest_release")"
tag="${latest_url##*/}"
if [[ ! $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-].*)?$ ]]; then
  echo "error: could not determine the latest Nerd Fonts release from '$latest_url'" >&2
  exit 1
fi

if [[ -f $version_file ]] && [[ $(<"$version_file") == "$tag" ]]; then
  echo "JetBrainsMono Nerd Font is already up to date ($tag)."
  exit 0
fi

mkdir -p "$font_root"
workdir="$(mktemp -d "$font_root/.JetBrainsMonoNerdFont.XXXXXX")"
cleanup() {
  rm -rf -- "$workdir"
}
trap cleanup EXIT

archive="$workdir/JetBrainsMono.tar.xz"
checksums="$workdir/SHA-256.txt"
release_base="https://github.com/ryanoasis/nerd-fonts/releases/download/$tag"

curl -fL --retry 3 "$release_base/JetBrainsMono.tar.xz" -o "$archive"
curl -fL --retry 3 "$release_base/SHA-256.txt" -o "$checksums"

expected="$(awk '$2 == "JetBrainsMono.tar.xz" { print $1; exit }' "$checksums")"
if [[ -z $expected ]]; then
  echo 'error: JetBrainsMono.tar.xz is missing from the Nerd Fonts checksum manifest' >&2
  exit 1
fi

actual="$(sha256sum "$archive" | awk '{ print $1 }')"
if [[ $actual != "$expected" ]]; then
  echo "error: checksum mismatch for JetBrainsMono.tar.xz" >&2
  exit 1
fi

extract_dir="$workdir/font"
mkdir -p "$extract_dir"
tar -xJf "$archive" -C "$extract_dir"
printf '%s\n' "$tag" > "$extract_dir/.nerd-font-version"

old_dir="${font_dir}.old"
rm -rf -- "$old_dir"
if [[ -e $font_dir || -L $font_dir ]]; then
  mv -- "$font_dir" "$old_dir"
fi

if ! mv -- "$extract_dir" "$font_dir"; then
  if [[ -e $old_dir || -L $old_dir ]]; then
    mv -- "$old_dir" "$font_dir"
  fi
  exit 1
fi

rm -rf -- "$old_dir"
fc-cache -f "$font_dir"
echo "Installed JetBrainsMono Nerd Font $tag to $font_dir"
