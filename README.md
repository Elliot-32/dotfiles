# dotfiles

使用 [mise](https://mise.jdx.dev/) 管理工具、系統套件與 dotfiles。

## 安裝

```bash
curl https://mise.run | sh
~/.local/bin/mise bootstrap --adopt https://github.com/Elliot-32/dotfiles.git --yes --force-dotfiles && exec zsh -l
```

Bootstrap 會依目前平台安裝套件、工具並套用設定。

中文輸入預設使用 Flathub 的 Fcitx 5 + 小麥注音；各發行版仍保留原生 IM module 供 host 應用使用。Arch 會自動準備 Paru。

## 常用指令

| 用途 | 指令 |
| --- | --- |
| 更新系統與工具 | `update` |
| 重新套用設定 | `mise bootstrap --yes --force-dotfiles` |
| 查看 dotfiles 狀態 | `mise bootstrap dotfiles status` |
| 納管檔案 | `mise bootstrap dotfiles track <path>` |
| 解除納管 | `mise bootstrap dotfiles untrack <path>` |
| 選擇主題（非 Omarchy） | `mise run theme` |
| 重新套用 WSL / Windows 整合 | `mise run bootstrap:windows` |
| 套用 Laptop 鍵盤設定 | `mise -E laptop run laptop:apply` |

dotfiles 會由 mise history/sync 自動同步。

Omarchy 使用自己的主題系統，不需要另外執行 Tinty 主題切換。

Laptop 鍵盤設定是 opt-in；先透過系統套件管理器安裝 `keyd`。套用後 `Print` 為 `Super`，`Ctrl+Print` 為 `PrintScreen`。
