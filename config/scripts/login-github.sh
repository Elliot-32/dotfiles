#!/bin/sh
set -eu

github_host=github.com
email_scope=user:email
sync_mode=sync
default_repository_name=dotfiles
gum_available=false

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

load_current_dotfiles_origin() {
  current_repository_url=
  current_repository_branch=main

  if ! origin_status=$(mise bootstrap dotfiles origin 2>/dev/null); then
    show_error "Could not read the current mise dotfiles origin"
    return 1
  fi

  case "$origin_status" in
    "no setup repository is connected;"*)
      return 0
      ;;
  esac

  current_repository_url=$(
    printf '%s\n' "$origin_status" |
      sed -n 's/^\(.*\) (branch [^)]*) declared in .*; mode .*$/\1/p'
  )
  parsed_branch=$(
    printf '%s\n' "$origin_status" |
      sed -n 's/^.* (branch \([^)]*\)) declared in .*; mode .*$/\1/p'
  )

  if [ -z "$current_repository_url" ] || [ -z "$parsed_branch" ]; then
    show_error "Could not parse the current mise dotfiles origin"
    return 1
  fi

  current_repository_branch=$parsed_branch
}

connect_dotfiles_origin() {
  repository_url=$1
  repository_branch=$2

  show_info "Connecting mise dotfiles history to $repository_url (branch $repository_branch)"
  if ! mise bootstrap dotfiles origin set \
    "$repository_url" \
    --branch "$repository_branch" \
    --sync "$sync_mode" \
    --yes; then
    show_error "Could not connect mise dotfiles history to $repository_url"
    return 1
  fi

  show_success "mise dotfiles origin now points to $repository_url"
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
  if ! existing_repository_branch=$(
    gh repo view "$existing_repository" \
      --json defaultBranchRef \
      --jq '.defaultBranchRef.name // empty' \
      2>/dev/null
  ); then
    show_error "Could not determine the default branch for $existing_repository"
    return 1
  fi

  if [ -z "$existing_repository_branch" ]; then
    existing_repository_branch=$current_repository_branch
  fi

  connect_dotfiles_origin "$existing_repository_url" "$existing_repository_branch"
}

create_repository() {
  if ! repository_visibility=$(
    gum choose \
      --label-delimiter ":" \
      --header "Choose the visibility for $github_login/$repository_name:" \
      "Private — Recommended for automatically synced dotfiles:private" \
      "Public — Anyone can see this repository:public"
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
  if ! connect_dotfiles_origin "$new_repository_url" "$current_repository_branch"; then
    show_error "The repository was created, but mise dotfiles history could not be connected"
    return 1
  fi

  show_success "Created and connected $new_repository_url"
}

configure_repository() {
  repository_name=$default_repository_name
  current_repository=
  current_repository_owner=

  if ! load_current_dotfiles_origin; then
    return 1
  fi

  if [ -n "$current_repository_url" ]; then
    repository_name=${current_repository_url##*/}
    repository_name=${repository_name%.git}
    if [ -z "$repository_name" ]; then
      repository_name=$default_repository_name
    fi

    if current_repository=$(
      gh repo view "$current_repository_url" \
        --json nameWithOwner \
        --jq '.nameWithOwner' \
        2>/dev/null
    ); then
      current_repository_owner=${current_repository%%/*}
    else
      show_warning "Could not identify the GitHub repository configured as the mise dotfiles origin"
    fi
  fi

  if [ -n "$current_repository_owner" ] &&
    same_github_login "$github_login" "$current_repository_owner"; then
    show_success "mise dotfiles origin already belongs to $github_login: $current_repository_url"
    return 0
  fi

  if ! require_interactive_gum; then
    return 1
  fi

  if [ -n "$current_repository_owner" ]; then
    repository_prompt="mise dotfiles origin belongs to $current_repository_owner, but GitHub is logged in as $github_login. Choose how to configure the dotfiles origin:"
  elif [ -n "$current_repository_url" ]; then
    repository_prompt="The current mise dotfiles origin is $current_repository_url. Choose how to configure the dotfiles origin for $github_login:"
  else
    repository_prompt="No mise dotfiles origin is connected. Choose how to configure one for $github_login:"
  fi

  if ! repository_action=$(
    gum choose \
      --label-delimiter ":" \
      --header "$repository_prompt" \
      "Use an existing repository — Connect mise history to one owned by $github_login:existing" \
      "Create a repository — Create $github_login/$repository_name and connect mise history:create" \
      "Skip — Keep the current mise dotfiles origin unchanged:skip"
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
      show_info "Repository setup skipped; the mise dotfiles origin was left unchanged"
      ;;
    *)
      show_error "gum returned an unexpected repository action"
      return 1
      ;;
  esac
}

main() {
  show_header

  if ! require_command gh || ! require_command git || ! require_command mise; then
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

trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

main "$@"
