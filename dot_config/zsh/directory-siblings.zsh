# Switch between sibling directories in the current directory's parent.

_directory_sibling_move() {
	local delta=$1 parent current target
	local -a siblings
	local -i current_index target_index

	parent=${PWD:h}
	current=${PWD:A}
	siblings=("$parent"/*(/N))
	current_index=0

	for (( current_index = 1; current_index <= ${#siblings}; current_index++ )); do
		[[ ${siblings[current_index]:A} == "$current" ]] && break
	done

	if (( current_index > ${#siblings} )); then
		zle -M "Current directory is not in its parent"
		return 0
	fi

	target_index=$((current_index + delta))
	if (( target_index < 1 || target_index > ${#siblings} )); then
		zle -M "No more sibling directories"
		return 0
	fi

	target=${siblings[target_index]}
	builtin cd -- "$target" || zle -M "Cannot enter sibling directory"
	_directory_refresh_prompt
}

directory-sibling-next() { _directory_sibling_move 1 }
directory-sibling-previous() { _directory_sibling_move -1 }
