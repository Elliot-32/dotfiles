# dotfiles

使用 [mise](https://mise.jdx.dev/) 管理開發工具、系統套件與 dotfiles，並以 [Topgrade](https://github.com/topgrade-rs/topgrade) 統一處理日常更新。此 repo 本身就是 mise global config，會安裝到 `$MISE_CONFIG_DIR`（預設 `~/.config/mise`）。

## 安裝
```bash
curl https://mise.run | sh
~/.local/bin/mise bootstrap --from-git https://github.com/Elliot-32/dotfiles.git --yes --force-dotfiles && exec zsh -l
```

在 WSL 中，bootstrap 會透過 `bootstrap:windows` task 使用 Gum 互動介面設定 Windows：安裝 Windows Git 與 JetBrainsMono Nerd Font，並讓使用者選擇 Windows Terminal 的配色與介面主題。目前可選 Catppuccin Mocha、Macchiato、Frappe、Latte、Tokyo Night 與 Dracula。

## 常用指令

| 用途 | 指令 |
| --- | --- |
| 檢查狀態 | `mise bootstrap status` |
| 更新工具、plugins、Flatpak 與字體 | `topgrade` |
| 套用所有變更 | `mise bootstrap --yes --force-dotfiles` |
| 重新設定 WSL 對應的 Windows / Windows Terminal 主題 | `mise run bootstrap:windows` |
| 查看 dotfiles 狀態 | `mise bootstrap dotfiles status` |
| 納管 dotfile | `mise bootstrap dotfiles add ~/.config/example/config` |
| 解除納管 dotfile | `mise bootstrap dotfiles unapply ~/.config/example/config` |
| 只套用 dotfiles | `mise bootstrap dotfiles apply --force --yes` |
| 安裝工具 | `mise install <tool>` |
| 使用指定 backend 安裝工具 | `mise install <backend>:<tool>` |
| 解除安裝工具 | `mise uninstall <tool>` |
| 新增全域工具 | `mise use -g <tool>` |
| 使用指定 backend 新增全域工具 | `mise use -g <backend>:<tool>` |
| 移除全域工具 | `mise unuse -g <tool>` |
| 安裝鎖定的 Yazi plugins | `ya pkg install` |
| 更新 Yazi plugins | `ya pkg upgrade` |


`mise bootstrap` 會套用 `~/.config/yazi` 並執行 `ya pkg install`，依 `.config/yazi/package.toml` 安裝鎖定版本的 Yazi plugins。

`install` / `uninstall` 只處理本機已安裝的工具版本，不會修改 mise 設定；`use` 會安裝工具並寫入設定，`unuse` 則會從設定中移除工具。若該工具版本已沒有其他 mise 設定需要，也會順便解除安裝。

Dotfiles 預設以 symlink 部署。`unapply` 不會修改 `[dotfiles]` 或刪除 repo 內的檔案，需要手動移除。
