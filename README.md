# dotfiles

使用 [mise](https://mise.jdx.dev/) 管理工具、系統套件與 dotfiles，並使用 mise history/sync 在多台機器間同步設定。

## 安裝

```bash
curl https://mise.run | sh
MISE_ENV_CONF_D=true ~/.local/bin/mise bootstrap --adopt https://github.com/Elliot-32/dotfiles.git --yes --force-dotfiles && exec zsh -l
```

## 同步

同步模式為 `settings.history.sync = "sync"`，由 `history-watch` 自動保存、發布及套用變更。

大部分使用者設定以 `mode = "track"` 直接管理原生路徑；mise 自身設定則由 setup repository 的 `config/` stream 管理。不需要對 `$MISE_CONFIG_DIR` 執行日常 `git pull` / `git push`。

需要手動操作時：

```bash
mise bootstrap dotfiles status
mise bootstrap dotfiles save
mise bootstrap dotfiles sync
mise bootstrap dotfiles pull
```

## 主題

`mise run theme` 使用 Tinty 的 Base24 schemes 與 Gum 選擇器統一切換主題。

- Ghostty 只更新 `~/.local/state/dotfiles/theme/ghostty.conf`；主設定透過 `config-file` include 它，Omarchy 的 include 仍具有較高優先權。
- gomi 的 `~/.config/gomi/config.yaml` 保持為同步的 base/fallback；主題會從 base 產生 `~/.local/state/dotfiles/theme/gomi.yaml`，互動式 `gomi` / `rm` 優先使用 runtime config。
- WSL 下會另外把同一個 Base24 palette merge 到 Windows Terminal 的 `schemes[]` / `themes[]`，不覆寫整份 `settings.json`。

Bootstrap 會執行隱藏的 `theme:init`，同步 Tinty schemes、重建 runtime templates，並重新套用上次的 scheme；第一次使用則套用 Catppuccin Macchiato。

## Nerd Font

`mise run nerd-font` 安裝或更新 JetBrainsMono Nerd Font。Linux 直接更新使用者字型；WSL 會改由 Windows 的 WinGet 安裝，因此可能出現 UAC 提示。

Topgrade 使用 `nerd-font:update`：Linux 會更新字型，WSL 則跳過 Windows 字型更新，避免排程或一般 Topgrade 流程被 UAC 卡住。

## 常用指令

| 用途 | 指令 |
| --- | --- |
| 更新系統與工具 | `topgrade` |
| 切換主題 | `mise run theme` |
| 安裝 / 更新 Nerd Font | `mise run nerd-font` |
| 重新套用 bootstrap | `mise bootstrap --yes --force-dotfiles` |
| 查看同步狀態 | `mise bootstrap dotfiles status` |
| 納管檔案 | `mise bootstrap dotfiles track <path>` |
| 解除納管 | `mise bootstrap dotfiles untrack <path>` |
| 安裝 / 移除工具 | `mise install <tool>` / `mise uninstall <tool>` |
| 加入 / 移除全域工具設定 | `mise use -g <tool>` / `mise unuse -g <tool>` |

`install` / `uninstall` 只改變本機已安裝版本；`use` / `unuse` 會修改 mise 設定。
