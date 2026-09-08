#!/bin/sh
set -eu

github_host=github.com
email_scope=user:email
gum_available=false
# Enabled only while origin temporarily points at a repository that has not
# received its initial push.
restore_origin_on_exit=false
original_repository_url=

if command -v gum >/dev/null 2>&1; then
  gum_available=true
fi

can_style_output() {
  [ "$gum_available" = true ] && [ -t 2 ]
}

show_message() (
  message_prefix=$1
  message_color=$2
  shift 2

  if can_style_output; then
    if gum log \
      --level none \
      --prefix "$message_prefix" \
      --prefix.foreground "$message_color" \
      "$*" >&2; then
      exit 0
    fi
  fi

  printf '%s %s\n' "$message_prefix" "$*" >&2
)

show_error() {
  show_message "✗" 196 "$@"
}

show_warning() {
  show_message "!" 214 "$@"
}

show_info() {
  show_message "•" 39 "$@"
}

show_success() {
  show_message "✓" 42 "$@"
}

show_header() {
  if can_style_output; then
    gum style \
      --border rounded \
      --border-foreground 212 \
      --padding "0 1" \
      --bold \
      "GitHub setup" >&2 || :
  fi
}

run_with_spinner() (
  spinner_title=$1
  shift

  if can_style_output; then
    gum spin \
      --spinner dot \
      --title "$spinner_title" \
      --show-error \
      -- "$@"
  else
    "$@"
  fi
)

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi

  show_error "$1 is not installed"
  return 1
}

require_interactive_gum() {
  if [ "$gum_available" != true ]; then
    show_error "gum is not installed"
    return 1
  fi

  if [ ! -t 0 ] || [ ! -t 2 ]; then
    show_error "An interactive terminal is required"
    return 1
  fi
}

same_github_login() (
  first_login=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  second_login=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
  [ "$first_login" = "$second_login" ]
)

restore_original_origin() {
  if [ "$restore_origin_on_exit" != true ]; then
    return 0
  fi

  restore_origin_on_exit=false
  if git remote set-url origin "$original_repository_url"; then
    show_warning "origin was restored to $original_repository_url"
  else
    show_error "Could not restore origin to $original_repository_url"
  fi
}

authenticate_github() (
  email_scope_query=".hosts[] | .[] | select(.active) | .scopes | split(\", \") | index(\"$email_scope\") != null"

  if ! gh auth status --active --hostname "$github_host" >/dev/null 2>&1; then
    if ! require_interactive_gum; then
      return 1
    fi

    if ! gum confirm \
      --affirmative "Sign in" \
      --negative "Skip" \
      "No active GitHub session was found. Sign in now?"; then
      show_info "GitHub setup skipped"
      return 2
    fi

    show_info "Opening GitHub browser login"
    if ! gh auth login \
      --hostname "$github_host" \
      --git-protocol https \
      --scopes "$email_scope" \
      --web; then
      show_error "GitHub authentication failed"
      return 1
    fi
  fi

  if ! has_email_scope=$(
    gh auth status \
      --hostname "$github_host" \
      --json hosts \
      --jq "$email_scope_query"
  ); then
    show_error "Could not read GitHub authentication scopes"
    return 1
  fi

  if [ "$has_email_scope" != true ]; then
    show_info "Requesting permission to read the primary GitHub email"
    if ! gh auth refresh \
      --hostname "$github_host" \
      --scopes "$email_scope"; then
      show_error "Could not add the $email_scope GitHub scope"
      return 1
    fi
  fi

  if ! run_with_spinner \
    "Configuring Git credentials..." \
    gh auth setup-git --hostname "$github_host"; then
    show_error "Could not configure Git to use GitHub credentials"
    return 1
  fi
)

load_github_profile() {
  # A non-whitespace separator keeps an empty email field intact for POSIX read.
  github_profile_separator=$(printf '\037')
  if ! github_profile_record=$(
    gh api user \
      --jq '[.login, (.name // .login), (.email // ""), (.id | tostring)] | join("\u001f")'
  ); then
    show_error "Could not load the GitHub profile"
    return 1
  fi

  IFS=$github_profile_separator read -r \
    github_login \
    git_user_name \
    git_user_email \
    github_user_id <<EOF
$github_profile_record
EOF

  if [ -z "$github_login" ] || [ -z "$git_user_name" ] || [ -z "$github_user_id" ]; then
    show_error "GitHub returned an incomplete profile"
    return 1
  fi
}

choose_git_email() {
  if ! primary_email=$(
    gh api user/emails \
      --jq 'map(select(.primary and .verified)) | first | .email // empty'
  ); then
    show_error "Could not load GitHub email addresses"
    return 1
  fi

  if [ -z "$primary_email" ]; then
    show_error "GitHub did not return a primary verified email"
    return 1
  fi

  if ! require_interactive_gum; then
    return 1
  fi

  noreply_email="${github_user_id}+${github_login}@users.noreply.github.com"
  if ! email_choice=$(
    gum choose \
      --label-delimiter ":" \
      --header "No public GitHub email is configured. Choose a Git email:" \
      "Keep my email private — $noreply_email:noreply" \
      "Use my primary email — $primary_email:primary"
  ); then
    show_warning "Git email selection was cancelled"
    return 1
  fi

  case "$email_choice" in
    noreply) git_user_email=$noreply_email ;;
    primary) git_user_email=$primary_email ;;
    *)
      show_error "gum returned an unexpected Git email selection"
      return 1
      ;;
  esac
}

configure_git_identity() {
  if [ -z "$git_user_email" ]; then
    if ! choose_git_email; then
      return 1
    fi
  fi

  if ! git config --global user.name "$git_user_name"; then
    show_error "Could not configure the global Git user name"
    return 1
  fi

  if ! git config --global user.email "$git_user_email"; then
    show_error "Could not configure the global Git email"
    return 1
  fi

  show_success "Git identity configured for $git_user_name <$git_user_email>"
}

configure_existing_repository() {
  while :; do
    if ! repository_input=$(
      gum input \
        --header "Enter the URL of a repository owned by $github_login:" \
        --value "https://$github_host/$github_login/$repository_name.git"
    ); then
      show_warning "Repository setup was cancelled"
      return 1
    fi

    if [ -z "$repository_input" ]; then
      show_error "A repository URL is required"
      continue
    fi

    if ! existing_repository=$(
      gh repo view "$repository_input" \
        --json nameWithOwner \
        --jq '.nameWithOwner' \
        2>/dev/null
    ); then
      show_error "Could not access that GitHub repository"
      continue
    fi

    existing_repository_owner=${existing_repository%%/*}
    if ! same_github_login "$github_login" "$existing_repository_owner"; then
      show_error "That repository belongs to $existing_repository_owner, not $github_login"
      continue
    fi

    break
  done

  existing_repository_url="https://$github_host/$existing_repository.git"
  if ! git remote set-url origin "$existing_repository_url"; then
    show_error "Could not update origin to $existing_repository_url"
    return 1
  fi

  show_success "origin now points to $existing_repository_url"
}

create_repository() {
  if ! repository_visibility=$(
    gum choose \
      --label-delimiter ":" \
      --header "Choose the visibility for $github_login/$repository_name:" \
      "Public — Anyone can see this repository:public" \
      "Private — Only people you grant access can see it:private"
  ); then
    show_warning "Repository setup was cancelled"
    return 1
  fi

  case "$repository_visibility" in
    public) visibility_flag=--public ;;
    private) visibility_flag=--private ;;
    *)
      show_error "gum returned an unexpected repository visibility"
      return 1
      ;;
  esac

  if ! run_with_spinner \
    "Creating $github_login/$repository_name..." \
    gh repo create "$github_login/$repository_name" "$visibility_flag"; then
    show_error "Could not create $github_login/$repository_name"
    return 1
  fi

  new_repository_url="https://$github_host/$github_login/$repository_name.git"
  restore_origin_on_exit=true
  if ! git remote set-url origin "$new_repository_url"; then
    show_error "The repository was created, but origin could not be updated"
    return 1
  fi

  if ! run_with_spinner \
    "Pushing the current branch..." \
    git push --set-upstream origin HEAD; then
    show_error "The repository was created, but the initial push failed"
    return 1
  fi

  restore_origin_on_exit=false
  show_success "Created and pushed $new_repository_url"
}

configure_repository() {
  if ! original_repository_url=$(git remote get-url origin 2>/dev/null); then
    show_info "No origin remote found; repository setup skipped"
    return 0
  fi

  if ! original_repository=$(
    gh repo view "$original_repository_url" \
      --json nameWithOwner \
      --jq '.nameWithOwner' \
      2>/dev/null
  ); then
    show_warning "Could not identify the GitHub repository configured as origin; remote setup skipped"
    return 0
  fi

  original_repository_owner=${original_repository%%/*}
  repository_name=${original_repository#*/}

  if same_github_login "$github_login" "$original_repository_owner"; then
    show_success "origin already belongs to $github_login: $original_repository_url"
    return 0
  fi

  if ! require_interactive_gum; then
    return 1
  fi

  if ! repository_action=$(
    gum choose \
      --label-delimiter ":" \
      --header "origin belongs to $original_repository_owner, but GitHub is logged in as $github_login. Choose how to configure origin:" \
      "Use an existing repository — Point origin to one owned by $github_login:existing" \
      "Create a repository — Create $github_login/$repository_name and push:create" \
      "Skip — Keep origin unchanged:skip"
  ); then
    show_warning "Repository setup was cancelled"
    return 1
  fi

  case "$repository_action" in
    existing)
      configure_existing_repository
      ;;
    create)
      create_repository
      ;;
    skip)
      show_info "Repository setup skipped; origin was left unchanged"
      ;;
    *)
      show_error "gum returned an unexpected repository action"
      return 1
      ;;
  esac
}

main() {
  show_header

  if ! require_command gh || ! require_command git; then
    return 1
  fi

  if authenticate_github; then
    :
  else
    authentication_status=$?
    if [ "$authentication_status" -eq 2 ]; then
      return 0
    fi
    return "$authentication_status"
  fi

  if ! load_github_profile; then
    return 1
  fi

  if ! configure_git_identity; then
    return 1
  fi

  if ! configure_repository; then
    return 1
  fi
}

trap 'restore_original_origin' 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

main "$@"
