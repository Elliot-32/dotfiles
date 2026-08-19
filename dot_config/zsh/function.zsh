# Load plain-text functions from function file
# Format: one per line as `name() { command }`
# Lines starting with `#` and blank lines are ignored.
_function_file="$HOME/.config/zsh/function"
if [[ -f "$_function_file" ]]; then
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" || "$line" == \#* ]] && continue
		eval "$line"
	done < "$_function_file"
fi
unset _function_file