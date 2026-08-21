# Shared state and module loader for directory navigation.
typeset -ga _directory_history
typeset -gi _directory_history_index=1
typeset -gi _directory_history_navigating=0
_directory_history=("$PWD")

autoload -Uz add-zsh-hook

_directory_refresh_prompt() {
	if (( ${+functions[_p9k_precmd]} )); then
		_p9k_precmd
		zle .reset-prompt
	else
		zle reset-prompt
	fi
}

_directory_navigation_dir="$HOME/.config/zsh"
source "$_directory_navigation_dir/directory-history.zsh"
source "$_directory_navigation_dir/directory-siblings.zsh"
source "$_directory_navigation_dir/directory-levels.zsh"
source "$_directory_navigation_dir/directory-bindings.zsh"
unset _directory_navigation_dir
