# ZLE widgets and Ghostty key bindings.

zle -N directory-history-select
zle -N directory-sibling-next
zle -N directory-sibling-previous
zle -N directory-child
zle -N directory-parent

# Legacy ESC-letter sequences and Ghostty CSI-u sequences.
bindkey -M emacs '\eh' directory-parent
bindkey -M emacs '\el' directory-child
bindkey -M emacs '\ej' directory-sibling-next
bindkey -M emacs '\ek' directory-sibling-previous
bindkey -M emacs '\er' directory-history-select
bindkey -M emacs '\e[104;3u' directory-parent
bindkey -M emacs '\e[108;3u' directory-child
bindkey -M emacs '\e[106;3u' directory-sibling-next
bindkey -M emacs '\e[107;3u' directory-sibling-previous
bindkey -M emacs '\e[114;3u' directory-history-select
