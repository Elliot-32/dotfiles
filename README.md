# dotfiles

使用 [mise](https://mise.jdx.dev/) 管理開發工具、系統套件與 dotfiles，並以 [Topgrade](https://github.com/topgrade-rs/topgrade) 統一處理日常更新。mise 2026.9.2 起，這個 repo 使用 mise dotfiles history/sync 作為設定與 `mise.lock` 的跨機同步來源。

## 安裝

```bash
curl https://mise.run | sh
~/.local/bin/mise bootstrap --from-git https://github.com/Elliot-32/dotfiles.git --yes --force-dotfiles && exec zsh -l
```

repo 具有 `.mise-history/format.toml`，因此 `--from-git` 會把它視為 mise setup repository。setup repo 的 `config/` 是 portable global-config root，會還原到目前的 `$MISE_CONFIG_DIR`；`home/` 則會還原到 `$HOME`。mise 會把 history 保存在自己的 bare store，不需要也不會把這個 Git repo checkout 到 `$MISE_CONFIG_DIR`。

在 WSL 中，bootstrap 會透過 `bootstrap:windows` task 使用 Gum 互動介面設定 Windows：安裝 Windows Git 與 JetBrainsMono Nerd Font，並讓使用者選擇 Windows Terminal 的配色與介面主題。目前可選 Catppuccin Mocha、Macchiato、Frappe、Latte、Tokyo Night 與 Dracula。

## 同步模型

一般使用者設定直接在原生位置使用 `mode = "track"`：例如 `~/.zshrc`、`~/.config/sheldon`、`~/.config/yazi`、`~/.config/ghostty/config`、Topgrade、Fcitx5 `profile`、`environment.d/90-fcitx5.conf` 與 `mise-completions-sync` registry 都是普通檔案/目錄，不再透過 `$MISE_CONFIG_DIR` 內的 source 建 symlink。遠端變更由 history pull 直接套到這些原生路徑。

mise 自身的 `config.toml`、`mise.lock`、`conf.d/`、scripts、Windows Terminal assets、hk 與 repo skill 仍位於 `$MISE_CONFIG_DIR`，並由 setup repository 的 portable `config/` stream 同步。Fcitx5 套件仍分別由 APT、DNF 與 Pacman 的 package fragments 安裝，但其使用者設定是跨 distro 共用的 native tracked files。`~/.gitconfig` 則只管理 repository defaults block，而不是同步整份可能含 machine-local identity 的檔案。

`mise.lock` 不再由 Topgrade 額外執行 `git add/commit/push`；Topgrade 只負責觸發日常更新，更新後的 tracked 檔案由 mise watcher 儲存並同步。

同步使用 `settings.history.sync = "sync"`。`history-watch` user service 會自動保存變更、發布已保存的 commits，並定期抓取及套用其他機器的變更。連線資訊放在 machine-local `config.local.toml`，不會進入共享 history；credential stores、secrets 與其他 machine-local 資料也不應納入 track。

### 既有 checkout 遷移

舊版把 repo checkout 直接放在 `$MISE_CONFIG_DIR`，並用 symlink / symlink-each 部署多數 dotfiles。遷移到 setup repository 前，先用**舊設定**解除這些 managed links，再把舊 checkout 移開；不要先把新 setup tree pull 進 `$MISE_CONFIG_DIR`：

```bash
mise bootstrap dotfiles unapply --yes
old="${MISE_CONFIG_DIR:-$HOME/.config/mise}"
mv "$old" "${old}.pre-history"
~/.local/bin/mise bootstrap --from-git https://github.com/Elliot-32/dotfiles.git --yes --force-dotfiles
mise bootstrap dotfiles status
```

確認新設定、history origin 與原生 dotfiles 都正常後，再自行刪除 `${MISE_CONFIG_DIR:-$HOME/.config/mise}.pre-history` 備份。`--from-git` 會辨識 setup marker、採用 setup repository 的 commit identity，並把 origin declaration 寫入 machine-local `config.local.toml`。之後由 `history-watch` 負責保存與同步，不再需要對 `$MISE_CONFIG_DIR` 做日常 Git pull/push。

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
| 套用剩餘 declarative entries | `mise bootstrap dotfiles apply --force --yes` |
| 安裝工具 | `mise install <tool>` |
| 使用指定 backend 安裝工具 | `mise install <backend>:<tool>` |
| 解除安裝工具 | `mise uninstall <tool>` |
| 新增全域工具 | `mise use -g <tool>` |
| 使用指定 backend 新增全域工具 | `mise use -g <backend>:<tool>` |
| 移除全域工具 | `mise unuse -g <tool>` |
| 安裝鎖定的 Yazi plugins | `ya pkg install` |
| 更新 Yazi plugins | `ya pkg upgrade` |

`mise bootstrap` 會先讓 setup/history 還原 `~/.config/yazi`，再由 bootstrap task 執行 `ya pkg install`，依 `~/.config/yazi/package.toml` 安裝鎖定版本的 Yazi plugins。

`install` / `uninstall` 只處理本機已安裝的工具版本，不會修改 mise 設定；`use` 會安裝工具並寫入設定，`unuse` 則會從設定中移除工具。若該工具版本已沒有其他 mise 設定需要，也會順便解除安裝。

對 `mode = "track"` 的原生檔案，`pull` 就是 deployment：遠端版本直接寫到應用程式實際讀取的路徑，不需要再跑 `apply`。`apply` 目前只保留給 `.gitconfig` managed block 這類仍有 declarative edit 語意的項目。
