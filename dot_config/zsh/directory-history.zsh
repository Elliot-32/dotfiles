# Directory history recording and fzf selection.

_directory_history_record() {
	(( _directory_history_navigating )) && return
	[[ $PWD == ${_directory_history[_directory_history_index]} ]] && return

	if (( _directory_history_index < ${#_directory_history} )); then
		_directory_history=(
			"${_directory_history[1,_directory_history_index]}"
			"$PWD"
		)
	else
		_directory_history+=("$PWD")
	fi

	if (( ${#_directory_history} > 1000 )); then
		_directory_history=("${_directory_history[2,-1]}")
	fi
	_directory_history_index=${#_directory_history}
}

directory-history-select() {
	local selected fzf_status _directory_selected_index

	if (( ${#_directory_history} < 2 )); then
		zle -M "No directory history"
		return 0
	fi

	zle -I
	selected=$(printf '%s\n' "${_directory_history[@]}" | fzf \
		--height=50% --reverse --border --prompt='directory-history> ' \
		--tac --select-1 --exit-0)
	fzf_status=$?
	(( fzf_status == 0 )) || return 0
	[[ -n $selected ]] || return 0

	for (( _directory_selected_index = 1; _directory_selected_index <= ${#_directory_history}; _directory_selected_index++ )); do
		[[ ${_directory_history[_directory_selected_index]} == "$selected" ]] || continue
		_directory_history_navigating=1
		if builtin cd -- "$selected"; then
			_directory_history_index=$_directory_selected_index
		fi
		_directory_history_navigating=0
		_directory_refresh_prompt
		return 0
	done
}

add-zsh-hook chpwd _directory_history_record
