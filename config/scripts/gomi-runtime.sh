#!/bin/sh
set -eu

runtime_config="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/theme/gomi.yaml"

if [ -f "$runtime_config" ]; then
  exec gomi --config "$runtime_config" "$@"
fi

exec gomi "$@"
