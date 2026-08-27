# ~/.zprofile: login-shell environment for zsh.

# Use the installation path directly: ~/.local/bin is not guaranteed to be on
# PATH yet in a fresh login environment.
if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh --shims)"
fi
