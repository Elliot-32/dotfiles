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

## Windows / WSL

在 WSL 執行 bootstrap 時，會一併設定 Windows 端需要的工具與字型，並在 Windows Terminal 註冊 `palette.json` 匯入，不會覆寫其他既有設定。

目前 Palette 尚未自動把產生的主題輸出安裝到 Windows Terminal；完整的主題同步會在 Palette 支援 runtime output/application 後接上。

## 常用指令

| 用途 | 指令 |
| --- | --- |
| 更新系統與工具 | `topgrade` |
| 重新套用 bootstrap | `mise bootstrap --yes --force-dotfiles` |
| 重新設定 Windows / Windows Terminal | `mise run bootstrap:windows` |
| 查看同步狀態 | `mise bootstrap dotfiles status` |
| 納管檔案 | `mise bootstrap dotfiles track <path>` |
| 解除納管 | `mise bootstrap dotfiles untrack <path>` |
| 安裝 / 移除工具 | `mise install <tool>` / `mise uninstall <tool>` |
| 加入 / 移除全域工具設定 | `mise use -g <tool>` / `mise unuse -g <tool>` |

`install` / `uninstall` 只改變本機已安裝版本；`use` / `unuse` 會修改 mise 設定。
