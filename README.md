# dotfiles

使用 [mise](https://mise.jdx.dev/) 管理工具、系統套件、dotfiles 與跨裝置同步。

## 安裝

```bash
curl https://mise.run | sh
MISE_ENV_CONF_D=true ~/.local/bin/mise bootstrap --adopt https://github.com/Elliot-32/dotfiles.git --yes --force-dotfiles && exec zsh -l
```

Bootstrap 會安裝需要的工具與套件、套用設定，並完成目前平台需要的初始化。

## 同步

設定會由 mise history/sync 自動同步。需要手動操作時可使用：

```bash
mise bootstrap dotfiles status
mise bootstrap dotfiles save
mise bootstrap dotfiles sync
mise bootstrap dotfiles pull
```

## 主題

一般環境使用 Tinty 統一切換主題；可直接套用 scheme，或使用互動式選擇器搜尋、預覽並決定是否保留主題：

```bash
tinty apply <scheme>
mise run theme:select
```

在 WSL 中，Windows Terminal 也會跟著 Tinty 主題一起更新。

Omarchy 環境則直接使用 Omarchy 的主題系統，不需要另外使用 Tinty。

## Windows / WSL

在 WSL bootstrap 時會一併安裝 Windows 端的 JetBrainsMono Nerd Font。需要再次執行 Windows 字體 bootstrap 時可使用：

```bash
mise run bootstrap:windows
```

## 常用指令

| 用途 | 指令 |
| --- | --- |
| 更新系統與工具 | `topgrade` |
| 重新套用 bootstrap | `mise bootstrap --yes --force-dotfiles` |
| 套用主題（非 Omarchy） | `tinty apply <scheme>` |
| 互動選擇 / 預覽 Tinty 主題 | `mise run theme:select` |
| 執行 Windows 字體 bootstrap | `mise run bootstrap:windows` |
| 查看同步狀態 | `mise bootstrap dotfiles status` |
| 納管檔案 | `mise bootstrap dotfiles track <path>` |
| 解除納管 | `mise bootstrap dotfiles untrack <path>` |
| 安裝 / 移除工具 | `mise install <tool>` / `mise uninstall <tool>` |
| 加入 / 移除全域工具設定 | `mise use -g <tool>` / `mise unuse -g <tool>` |

`install` / `uninstall` 只改變本機已安裝版本；`use` / `unuse` 會修改 mise 設定。
