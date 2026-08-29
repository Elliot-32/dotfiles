#!/bin/sh
set -eu

github_host=github.com
email_scope=user:email

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is not installed" >&2
  exit 1
fi

if ! gh auth status --active --hostname "$github_host" >/dev/null 2>&1; then
  gh auth login \
    --hostname "$github_host" \
    --git-protocol https \
    --scopes "$email_scope" \
    --web
fi

has_email_scope=$(
  gh auth status \
    --hostname "$github_host" \
    --json hosts \
    --jq '.hosts["github.com"][] | select(.active) | .scopes | split(", ") | index("user:email") != null'
)

if [ "$has_email_scope" != true ]; then
  gh auth refresh \
    --hostname "$github_host" \
    --scopes "$email_scope"
fi

gh auth setup-git --hostname "$github_host"

git_user_name=$(gh api user --jq '.name // .login')
git_user_email=$(
  gh api user/emails \
    --jq 'map(select(.primary and .verified)) | first | .email // empty'
)

if [ -z "$git_user_email" ]; then
  echo "GitHub did not return a primary verified email" >&2
  exit 1
fi

git config --global user.name "$git_user_name"
git config --global user.email "$git_user_email"
