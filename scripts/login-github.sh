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
git_user_email=$(gh api user --jq '.email // empty')

if [ -z "$git_user_email" ]; then
  primary_email=$(
    gh api user/emails \
      --jq 'map(select(.primary and .verified)) | first | .email // empty'
  )

  if [ -z "$primary_email" ]; then
    echo "GitHub did not return a primary verified email" >&2
    exit 1
  fi

  if ! command -v gum >/dev/null 2>&1; then
    echo "gum is not installed" >&2
    exit 1
  fi

  if [ ! -t 0 ]; then
    echo "An interactive terminal is required to choose a Git email" >&2
    exit 1
  fi

  noreply_email=$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')
  noreply_choice="GitHub noreply — $noreply_email"
  primary_choice="Primary email — $primary_email"

  if ! email_choice=$(
    gum choose \
      --header "No public GitHub email is configured. Choose a Git email:" \
      "$noreply_choice" \
      "$primary_choice"
  ); then
    echo "Git email selection was cancelled" >&2
    exit 1
  fi

  case "$email_choice" in
    "$noreply_choice") git_user_email=$noreply_email ;;
    "$primary_choice") git_user_email=$primary_email ;;
    *)
      echo "gum returned an unexpected Git email selection" >&2
      exit 1
      ;;
  esac
fi

git config --global user.name "$git_user_name"
git config --global user.email "$git_user_email"
