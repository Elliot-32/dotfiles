# dotfiles

使用 [mise](https://mise.jdx.dev/) 管理開發工具、系統套件與 dotfiles，並以 [Topgrade](https://github.com/topgrade-rs/topgrade) 統一處理日常更新。mise 2026.9.2 起，這個 repo 同時使用 mise dotfiles history/sync 作為設定與 `mise.lock` 的跨機同步來源。

## 安裝

```bash
curl https://mise.run | sh
~/.local/bin/mise bootstrap --from-git https://github.com/Elliot-32/dotfiles.git --yes --force-dotfiles && exec zsh -l
```

repo 具有 `.mise-history/format.toml` 後，`--from-git` 會把它視為 mise setup repository：共享設定與 tracked sources 會進入 mise 自己的 history store，再由普通 `mise bootstrap` 套用 packages、tools、dotfiles、WSL/Windows tasks 等既有流程，不需要把 setup repo checkout 到 `$MISE_CONFIG_DIR`。

在 WSL 中，bootstrap 會透過 `bootstrap:windows` task 使用 Gum 互動介面設定 Windows：安裝 Windows Git 與 JetBrainsMono Nerd Font，並讓使用者選擇 Windows Terminal 的配色與介面主題。目前可選 Catppuccin Mocha、Macchiato、Frappe、Latte、Tokyo Night 與 Dracula。

## 同步模型

`config.toml`、`mise.lock`、`miserc.toml`、`conf.d/`、scripts、Windows Terminal assets，以及實際提供給 `[dotfiles]` 的 source files/directories 都使用 `mode = "track"` 納入 mise history。`mise.lock` 不再由 Topgrade 額外執行 `git add/commit/push`；Topgrade 只負責觸發日常更新，更新後的 tracked 檔案由 mise watcher 儲存並同步。

同步使用 `settings.history.sync = "sync"`。`history-watch` user service 會自動保存變更、發布已保存的 commits，並定期抓取及套用其他機器的變更。連線資訊放在 machine-local `config.local.toml`，不會進入共享 history；credential stores、secrets 與其他 machine-local 資料也不應納入 track。

### 既有 checkout 遷移

第一次從舊的普通 Git checkout 遷移時，先更新到包含 setup marker 的版本，然後**先用 `--from-git` 讓 mise onboarding 接管 history**，不要先跑 `dotfiles save` / watcher，也不要用 `origin set` 建立一條無共同祖先的本機 history：

```bash
git -C "${MISE_CONFIG_DIR:-$HOME/.config/mise}" pull --ff-only
mise bootstrap --from-git https://github.com/Elliot-32/dotfiles.git --yes --force-dotfiles
mise bootstrap dotfiles status
```

`--from-git` 會辨識 `.mise-history/format.toml`，直接採用 setup repository 的 commit identity 並把 origin declaration 寫入 machine-local `config.local.toml`。之後由 `history-watch` 負責保存與同步，不再需要對 `$MISE_CONFIG_DIR` 執行日常 Git pull/push。

需要立即交換變更時可手動執行：

```bash
mise bootstrap dotfiles save
mise bootstrap dotfiles sync
mise bootstrap dotfiles pull
```

遇到 conflict 時，mise 會暫停整個 setup 的 publication/application；使用 `mise bootstrap dotfiles status` 查看衝突，再以 `pull --take-remote <path>` 或 `pull --keep-local <path>` 解決。

## 常用指令

| 用途 | 指令 |
| --- | --- |
| 檢查狀態 | `mise bootstrap status` |
| 更新工具、plugins、Flatpak 與字體 | `topgrade` |
| 套用所有變更 | `mise bootstrap --yes --force-dotfiles` |
| 重新設定 WSL 對應的 Windows / Windows Terminal 主題 | `mise run bootstrap:windows` |
| 查看 dotfiles/sync 狀態 | `mise bootstrap dotfiles status` |
| 手動保存 tracked files | `mise bootstrap dotfiles save` |
| 立即同步 | `mise bootstrap dotfiles sync` |
| 套用遠端 pending 變更 | `mise bootstrap dotfiles pull` |
| 納管原生檔案 | `mise bootstrap dotfiles track ~/.config/example/config` |
| 解除 track | `mise bootstrap dotfiles untrack ~/.config/example/config` |
| 只套用 declarative dotfiles | `mise bootstrap dotfiles apply --force --yes` |
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

既有 declarative dotfiles 仍保留 symlink / symlink-each 部署；track/sync 管理的是它們的 source 與 setup configuration。`pull` 負責套用其他機器共享的 tracked 變更，`apply`/`mise bootstrap` 則繼續負責 declarative deployment，兩者用途不同。
