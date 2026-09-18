#!/bin/sh
set -eu

version="3.1.1"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/mise-bootstrap"
stamp="$state_dir/fcitx5-mcbopomofo.version"
input_method="/usr/share/fcitx5/inputmethod/mcbopomofo.conf"

remove_chewing() {
  if command -v dpkg-query >/dev/null 2>&1 &&
    dpkg-query -W -f='${Status}' fcitx5-chewing 2>/dev/null | grep -q 'ok installed'; then
    sudo apt-get remove --yes fcitx5-chewing
  elif command -v rpm >/dev/null 2>&1 &&
    rpm -q fcitx5-chewing >/dev/null 2>&1; then
    sudo dnf remove --assumeyes fcitx5-chewing
  fi
}

if [ -f "$stamp" ] &&
  [ "$(cat "$stamp")" = "$version" ] &&
  [ -f "$input_method" ]; then
  remove_chewing
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

archive="$tmp_dir/fcitx5-mcbopomofo.tar.gz"
src_dir="$tmp_dir/fcitx5-mcbopomofo-$version"

curl -fsSL   "https://github.com/openvanilla/fcitx5-mcbopomofo/archive/refs/tags/$version.tar.gz"   -o "$archive"
tar -xzf "$archive" -C "$tmp_dir"

cmake -S "$src_dir" -B "$src_dir/build"   -DCMAKE_INSTALL_PREFIX=/usr   -DCMAKE_BUILD_TYPE=Release   -DENABLE_TEST=Off
cmake --build "$src_dir/build"
sudo cmake --install "$src_dir/build"

if command -v update-icon-caches >/dev/null 2>&1; then
  sudo update-icon-caches /usr/share/icons/*
fi

remove_chewing
mkdir -p "$state_dir"
printf '%s\n' "$version" >"$stamp"
