# ~/.profile: login-shell environment.

# Keep mise shims available outside interactive zsh sessions.
if [ -x "$HOME/.local/bin/mise" ]; then
  eval "$("$HOME/.local/bin/mise" activate bash --shims)"
fi

# Bash login shells still load ~/.bashrc when present.
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
