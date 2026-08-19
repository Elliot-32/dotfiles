# Load PATH directories from path file
# Format: one directory per line (supports $VAR expansion)
# Lines starting with `#` and blank lines are ignored.
_path_file="$HOME/.config/zsh/path"
if [[ -f "$_path_file" ]]; then
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" || "$line" == \#* ]] && continue
		local _dir="${(e)line}"
		[[ -d "$_dir" ]] || continue
		export PATH="$_dir:$PATH"
	done < "$_path_file"
fi
unset _path_file