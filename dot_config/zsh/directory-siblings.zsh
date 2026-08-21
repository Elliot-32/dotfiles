# Select a sibling directory in the current directory's parent.

_directory_sibling_select() {
	local parent selected fzf_status
	local -a siblings

	parent=${PWD:h}
	siblings=("$parent"/*(/N))

	if (( ! ${#siblings} )); then
		zle -M "No sibling directories"
		return 0
	fi

	zle -I
	selected=$(printf '%s\n' "${siblings[@]}" | fzf \
		--height=50% --reverse --border --prompt='sibling> ' \
		--bind='alt-j:down,alt-k:up' \
		--select-1 --exit-0)
	fzf_status=$?
	_directory_refresh_prompt
	(( fzf_status == 0 )) || return 0
	[[ -n $selected ]] || return 0

	builtin cd -- "$selected" || zle -M "Cannot enter sibling directory"
	_directory_refresh_prompt
}

directory-sibling-next() { _directory_sibling_select }
directory-sibling-previous() { _directory_sibling_select }
