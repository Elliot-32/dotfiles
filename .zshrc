# Atuin PTY proxy must be initialized before Powerlevel10k instant prompt.
PATH="$HOME/.local/share/mise/installs/atuin/latest/.mise-bins:$PATH" \
  eval "$("$HOME/.local/share/mise/installs/atuin/latest/.mise-bins/atuin" pty-proxy init zsh)"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

eval "$("$HOME/.local/bin/mise" activate zsh)"

# yazi
y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  command rm -f -- "$tmp"
}

md() {
  [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1"
}

# De-duplicate PATH/fpath (nested shells would otherwise keep growing them).
typeset -U path fpath FPATH

# History
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=10000
setopt hist_ignore_dups hist_ignore_space hist_verify share_history append_history

# Environment
export GPG_TTY=$TTY

# Autoload functions
autoload -Uz zmv

# Shell options: http://zsh.sourceforge.net/Doc/Release/Options.html.
setopt glob_dots     # no special treatment for file names with a leading dot

# Generate rgrc aliases without overriding aliases declared in mise.toml.
eval "$(rgrc --aliases --except ls)"

# Convert rgrc aliases to wrapper functions: functions are not expanded for
# completion lookup, so systemctl/podman/... keep their own completions.
for _rgrc_cmd in ${(k)aliases}; do
  [[ $aliases[$_rgrc_cmd] == "rgrc "* ]] || continue
  functions[$_rgrc_cmd]="${aliases[$_rgrc_cmd]} \"\$@\""
  unalias $_rgrc_cmd
done
unset _rgrc_cmd

# Configure completion before Sheldon runs compinit and loads plugins.
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no

# Use Emacs keymap before plugins register their key bindings.
bindkey -e

# Sheldon manages completion fpath, compinit, shell integrations, and plugins
# in dependency order.
eval "$(sheldon source)"

# Completions for personal functions (compinit has run above).
compdef _directories md

# Key bindings
bindkey '^Z' undo
bindkey '\e/' redo
bindkey '^H' backward-kill-word                    # Ctrl+Backspace
bindkey '^[[3;5~' kill-word                        # Ctrl+Delete
bindkey '^[[1;5D' backward-word                    # Ctrl+Left
bindkey '^[[1;5C' forward-word                     # Ctrl+Right

# Ctrl+V pastes clipboard via widget (terminal passes ^V through to zsh).
paste-clipboard() {
  local clip
  clip=$(wl-paste --no-newline 2>/dev/null) || clip=$(xclip -o -selection clipboard 2>/dev/null) || return 1
  LBUFFER+=$clip
}
zle -N paste-clipboard
bindkey '^V' paste-clipboard

# Shift+Enter inserts a newline (Ghostty sends \n, i.e. ^J).
insert-newline() { LBUFFER+=$'\n' }
zle -N insert-newline
bindkey '^J' insert-newline

# Ctrl+Shift+Z -> redo (Ghostty sends it as CSI u).
bindkey '\e[122;6u' redo

autoload -Uz history-search-end

zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end

bindkey -M emacs '^[[A' history-beginning-search-backward-end
bindkey -M emacs '^[[B' history-beginning-search-forward-end
bindkey -M emacs '^P' history-beginning-search-backward-end
bindkey -M emacs '^N' history-beginning-search-forward-end

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
