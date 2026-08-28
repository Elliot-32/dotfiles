#!/bin/sh
set -eu

if ! gh auth status --active --hostname github.com >/dev/null 2>&1; then
  gh auth login --hostname github.com
fi

gh auth setup-git --hostname github.com

prompt_git_config() {
  key=$1
  label=$2
  value=$3
  env_name=$4

  if git config --global --includes --get "$key" >/dev/null 2>&1; then
    return
  fi

  while [ -z "$value" ]; do
    if [ ! -t 0 ]; then
      echo "$label is not configured. Rerun mise bootstrap interactively or set $env_name." >&2
      exit 1
    fi

    printf '%s: ' "$label" >&2
    IFS= read -r value
  done

  git config --global "$key" "$value"
}

prompt_git_config user.name "Git user name" "${GIT_USER_NAME:-}" GIT_USER_NAME
prompt_git_config user.email "Git user email" "${GIT_USER_EMAIL:-}" GIT_USER_EMAIL
