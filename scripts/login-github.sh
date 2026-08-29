#!/bin/sh
set -eu

github_host=github.com

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is not installed" >&2
  exit 1
fi

if ! gh auth status --active --hostname "$github_host" >/dev/null 2>&1; then
  gh auth login \
    --hostname "$github_host" \
    --git-protocol https \
    --web
fi

gh auth setup-git --hostname "$github_host"

git_user_name=$(gh api user --jq '.name // .login')
git_user_email=$(
  gh api user --jq '
    if (.email // "") != "" then
      .email
    else
      "\(.id)+\(.login)@users.noreply.github.com"
    end
  '
)

git config --global user.name "$git_user_name"
git config --global user.email "$git_user_email"
