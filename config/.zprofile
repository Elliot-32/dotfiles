# Make mise available in login shells before activating its shims.
export PATH="$HOME/.local/bin:$PATH"

eval "$(mise activate zsh --shims)"
