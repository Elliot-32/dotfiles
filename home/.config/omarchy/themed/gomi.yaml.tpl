core:
  trash:
    strategy: xdg
    home_fallback: true
    forbidden_paths:
      - "$HOME/.local/share/Trash"
      - "$HOME/.trash"
      - "$XDG_DATA_HOME/Trash"
      - "/tmp/Trash"
      - "/var/tmp/Trash"
      - "$HOME/.gomi"
      - "$HOME/.config/mise"
      - "$MISE_CONFIG_DIR"
      - "$HOME/.miserc.toml"
      - "$HOME/.config/gomi/config.yaml"
      - "$HOME/.zshrc"
      - "$HOME/.zprofile"
      - "$HOME/.config/sheldon"
      - "$HOME/.config/topgrade.toml"
      - "$HOME/.config/topgrade.systemd.toml"
      - "/"
      - "/etc"
      - "/usr"
      - "/var"
      - "/bin"
      - "/sbin"
      - "/lib"
      - "/lib64"

ui:
  preview:
    syntax_highlight: true
    colorscheme: catppuccin-mocha
    directory_command: eza -la --icons=always --color=always
  style:
    list_view:
      cursor: "{{ accent }}"
      selected: "{{ green }}"
      filter_match: "{{ yellow }}"
      filter_prompt: "{{ blue }}"
      indent_on_select: false
    detail_view:
      border: "{{ foreground }}"
      info_pane:
        deleted_from:
          fg: "{{ color7 }}"
          bg: "{{ background }}"
        deleted_at:
          fg: "{{ color7 }}"
          bg: "{{ background }}"
      preview_pane:
        border: "{{ color8 }}"
        size:
          fg: "{{ color7 }}"
          bg: "{{ color0 }}"
        scroll:
          fg: "{{ color7 }}"
          bg: "{{ color0 }}"
    deletion_dialog: "{{ red }}"

logging:
  enabled: true
  level: info
  rotation:
    max_size: 10MB
    max_files: 3
