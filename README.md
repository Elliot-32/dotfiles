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

## Windows Terminal

WSL 環境下的 `bootstrap:windows` 會安裝 Windows 端的 Git 與 JetBrainsMono Nerd Font，並以 Microsoft `jsonc-parser` 對既有 Windows Terminal `settings.json` 做最小 JSONC 修改，確保頂層 `import` 包含 `palette.json`。既有的註解、其他 import 與其餘設定不會被整份重新序列化。

`jsonc-parser` 固定使用 `3.3.1`，只安裝到 `~/.cache/elliot-dotfiles/windows-terminal-jsonc`，不會在 `$MISE_CONFIG_DIR` 產生 `node_modules`。WSL 另外追蹤 `~/.config/palette/config.toml` 與 `~/.config/palette/template/palette.json`；後者是 Windows Terminal 的 Palette canonical template，同時定義固定名稱的 `Palette` color scheme 與 UI theme，並使用 Base16-compatible Tinted placeholders。Palette config 對這份 Windows Terminal template 明確設定 `omarchy = false`，因此 Omarchy target 不會生成它；Tinty target 仍維持預設啟用。實際輸出的 `palette.json` 應放在對應的 Windows Terminal `settings.json` 同一目錄。

## 常用指令

| 用途 | 指令 |
| --- | --- |
| 更新系統與工具 | `topgrade` |
| 重新套用 bootstrap | `mise bootstrap --yes --force-dotfiles` |
| 設定 Windows / Windows Terminal | `mise run bootstrap:windows` |
| 查看同步狀態 | `mise bootstrap dotfiles status` |
| 納管檔案 | `mise bootstrap dotfiles track <path>` |
| 解除納管 | `mise bootstrap dotfiles untrack <path>` |
| 安裝 / 移除工具 | `mise install <tool>` / `mise uninstall <tool>` |
| 加入 / 移除全域工具設定 | `mise use -g <tool>` / `mise unuse -g <tool>` |

`install` / `uninstall` 只改變本機已安裝版本；`use` / `unuse` 會修改 mise 設定。
