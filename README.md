# dotfiles

使用 [mise](https://mise.jdx.dev/) 管理工具、系統套件、dotfiles 與跨裝置同步。

## 安裝

```bash
curl https://mise.run | sh
MISE_ENV_CONF_D=true ~/.local/bin/mise bootstrap --adopt https://github.com/Elliot-32/dotfiles.git --yes --force-dotfiles && exec zsh -l
```

Bootstrap 會安裝需要的工具與套件、套用設定，並完成各平台對應的初始化。

## 同步

設定會由 mise history/sync 自動同步。需要手動操作時可使用：

```bash
mise bootstrap dotfiles status
mise bootstrap dotfiles save
mise bootstrap dotfiles sync
mise bootstrap dotfiles pull
```

## 主題

一般環境由 Tinty 統一套用主題：Ghostty 使用 `tinted-terminal`，gomi 與 Windows Terminal 使用這個 repo 維護的 Tinty templates。Bootstrap 的 `bootstrap:theme` task 會執行 `tinty sync`、build 本地 templates，再以 `tinty init` 套用目前或預設主題。

Windows Terminal 也完全屬於 Tinty 流程。每次 `tinty apply` 時，Tinty hook 都會更新 `tinty.json`、確保 Windows Terminal 的 `settings.json` 匯入它，並清理舊的 `palette.json` import/file；因此不需要另外執行 Windows bootstrap 來套用或修復主題。

`mise run theme:select` 是 Tinty 的互動式主題選擇器。它會用 Gum 搜尋 Base16/Base24 schemes；選中候選主題後立即執行 `tinty apply`，讓所有 Tinty targets 同步切換作為實際預覽，接著可以保留主題、繼續選擇，或還原執行選擇器前的主題。

Omarchy 環境則完全交給 Omarchy 管理主題。平台設定會用 `disable_tools` 排除 `cargo:tinty`，因此 bootstrap 不會安裝 Tinty；`bootstrap:theme` 也會覆寫成 no-op。Ghostty 直接讀取 Omarchy 的 current theme config；gomi 的 `~/.config/omarchy/themed/gomi.yaml.tpl` 會產生 `~/.local/state/omarchy/current/theme/gomi.yaml`，再由共用 `theme-set` hook 依 `~/.config/omarchy/themed-links.toml` 建立 symlink 到 `~/.config/gomi/config.yaml`。

新增其他 Omarchy themed config 時，只要增加 template 與一筆 link：

```toml
[[links]]
template = "gomi.yaml"
output = "~/.config/gomi/config.yaml"
```

`dasel` 已由 mise 全域工具設定安裝；bootstrap 會在 tools 安裝完成後先執行一次 themed-links hook，之後則由 Omarchy 的 `theme-set` hook 在每次換主題後重新建立連結。

## Windows / WSL

在 WSL 執行 bootstrap 時，`bootstrap:windows` 只負責透過 WinGet 安裝 Windows 端的 JetBrainsMono Nerd Font。Windows Terminal 主題由 Tinty/theme task 負責，不再由 Windows bootstrap 修改。

## 常用指令

| 用途 | 指令 |
| --- | --- |
| 更新系統與工具 | `topgrade` |
| 重新套用 bootstrap | `mise bootstrap --yes --force-dotfiles` |
| 套用主題（非 Omarchy） | `tinty apply <scheme>` |
| 互動選擇 / 預覽 Tinty 主題 | `mise run theme:select` |
| 重新安裝 / 設定 Windows 字體 | `mise run bootstrap:windows` |
| 查看同步狀態 | `mise bootstrap dotfiles status` |
| 納管檔案 | `mise bootstrap dotfiles track <path>` |
| 解除納管 | `mise bootstrap dotfiles untrack <path>` |
| 安裝 / 移除工具 | `mise install <tool>` / `mise uninstall <tool>` |
| 加入 / 移除全域工具設定 | `mise use -g <tool>` / `mise unuse -g <tool>` |

`install` / `uninstall` 只改變本機已安裝版本；`use` / `unuse` 會修改 mise 設定。
