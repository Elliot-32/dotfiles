# Move to the parent directory or select a child directory.

directory-parent() {
	builtin cd .. || zle -M "Cannot enter parent directory"
	_directory_refresh_prompt
}

directory-child() {
	local selected
	local -a children
	children=(./*(/N))

	if (( ! ${#children} )); then
		zle -M "No subdirectories"
		return 0
	fi

	if (( ${#children} == 1 )); then
		selected=${children[1]}
	else
		zle -I
		selected=$(printf '%s\n' "${children[@]}" | fzf \
			--height=40% --reverse --border --prompt='cd> ' \
			--select-1 --exit-0)
		local fzf_status=$?
		_directory_refresh_prompt
		(( fzf_status == 0 )) || return 0
	fi

	selected=${selected#./}
	builtin cd -- "$selected" || zle -M "Cannot enter: $selected"
	_directory_refresh_prompt
}
