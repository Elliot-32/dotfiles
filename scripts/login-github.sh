#!/bin/sh
set -eu

github_host=github.com
email_scope=user:email

require_interactive_gum() {
  if ! command -v gum >/dev/null 2>&1; then
    echo "gum is not installed" >&2
    return 1
  fi

  if [ ! -t 0 ]; then
    echo "An interactive terminal is required" >&2
    return 1
  fi
}

same_github_login() {
  first_login=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  second_login=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
  [ "$first_login" = "$second_login" ]
}

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

github_login=$(gh api user --jq '.login')
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

  if ! require_interactive_gum; then
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

if ! original_repository_url=$(git remote get-url origin 2>/dev/null); then
  exit 0
fi

if ! original_repository=$(
  gh repo view "$original_repository_url" \
    --json nameWithOwner \
    --jq '.nameWithOwner' \
    2>/dev/null
); then
  echo "Could not identify the GitHub repository configured as origin; skipping remote setup" >&2
  exit 0
fi

original_repository_owner=${original_repository%%/*}
repository_name=${original_repository#*/}

if same_github_login "$github_login" "$original_repository_owner"; then
  exit 0
fi

if ! require_interactive_gum; then
  exit 1
fi

existing_repository_choice="Use an existing repository"
create_repository_choice="Create a repository"
skip_repository_choice="Skip"

if ! repository_action=$(
  gum choose \
    --header "origin belongs to $original_repository_owner, but GitHub is logged in as $github_login. Choose how to configure origin:" \
    "$existing_repository_choice" \
    "$create_repository_choice" \
    "$skip_repository_choice"
); then
  echo "Repository setup was cancelled" >&2
  exit 1
fi

case "$repository_action" in
  "$existing_repository_choice")
    while :; do
      if ! repository_input=$(
        gum input \
          --header "Enter the URL of a repository owned by $github_login:" \
          --placeholder "https://$github_host/$github_login/$repository_name.git"
      ); then
        echo "Repository setup was cancelled" >&2
        exit 1
      fi

      if [ -z "$repository_input" ]; then
        echo "A repository URL is required" >&2
        continue
      fi

      if ! existing_repository=$(
        gh repo view "$repository_input" \
          --json nameWithOwner \
          --jq '.nameWithOwner' \
          2>/dev/null
      ); then
        echo "Could not access that GitHub repository" >&2
        continue
      fi

      existing_repository_owner=${existing_repository%%/*}
      if ! same_github_login "$github_login" "$existing_repository_owner"; then
        echo "That repository belongs to $existing_repository_owner, not $github_login" >&2
        continue
      fi

      break
    done

    git remote set-url origin "https://$github_host/$existing_repository.git"
    ;;
  "$create_repository_choice")
    public_repository_choice="Public"
    private_repository_choice="Private"

    if ! repository_visibility=$(
      gum choose \
        --header "Choose the visibility for $github_login/$repository_name:" \
        "$public_repository_choice" \
        "$private_repository_choice"
    ); then
      echo "Repository setup was cancelled" >&2
      exit 1
    fi

    case "$repository_visibility" in
      "$public_repository_choice") visibility_flag=--public ;;
      "$private_repository_choice") visibility_flag=--private ;;
      *)
        echo "gum returned an unexpected repository visibility" >&2
        exit 1
        ;;
    esac

    if ! gh repo create "$github_login/$repository_name" "$visibility_flag"; then
      echo "Could not create $github_login/$repository_name" >&2
      exit 1
    fi

    new_repository_url="https://$github_host/$github_login/$repository_name.git"
    git remote set-url origin "$new_repository_url"

    if ! git push --set-upstream origin HEAD; then
      git remote set-url origin "$original_repository_url" || :
      echo "The repository was created, but the initial push failed; origin was restored" >&2
      exit 1
    fi
    ;;
  "$skip_repository_choice") ;;
  *)
    echo "gum returned an unexpected repository action" >&2
    exit 1
    ;;
esac
