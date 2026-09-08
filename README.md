# dotfiles

使用 [mise](https://mise.jdx.dev/) 管理工具、系統套件與 dotfiles，並使用 mise history/sync 在多台機器間同步設定。

## 安裝

```bash
curl https://mise.run | sh
MISE_ENV_CONF_D=true ~/.local/bin/mise bootstrap --from-git https://github.com/Elliot-32/dotfiles.git --yes --force-dotfiles && exec zsh -l
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
