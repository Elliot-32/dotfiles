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

Omarchy 環境則完全交給 Omarchy 管理主題，`bootstrap:theme` 會被平台設定覆寫成 no-op，不執行 Tinty。Ghostty 直接讀取 Omarchy 的 current theme config；gomi 的 `~/.config/omarchy/themed/gomi.yaml.tpl` 會產生 `~/.local/state/omarchy/current/theme/gomi.yaml`，再由共用 `theme-set` hook 依 `~/.config/omarchy/themed-links.toml` 建立 symlink 到 `~/.config/gomi/config.yaml`。

新增其他 Omarchy themed config 時，只要增加 template 與一筆 link：

```toml
[[links]]
template = "gomi.yaml"
output = "~/.config/gomi/config.yaml"
```

`dasel` 已由 mise 全域工具設定安裝；bootstrap 會在 tools 安裝完成後先執行一次 themed-links hook，之後則由 Omarchy 的 `theme-set` hook 在每次換主題後重新建立連結。

## Windows / WSL

在 WSL 執行 bootstrap 時，會一併設定 Windows 端需要的工具與字型，並在 Windows Terminal 註冊 `palette.json` 匯入，不會覆寫其他既有設定。Tinty 套用主題時會更新這個匯入檔。

## 常用指令

| 用途 | 指令 |
| --- | --- |
| 更新系統與工具 | `topgrade` |
| 重新套用 bootstrap | `mise bootstrap --yes --force-dotfiles` |
| 套用主題（非 Omarchy） | `tinty apply <scheme>` |
| 重新設定 Windows / Windows Terminal | `mise run bootstrap:windows` |
| 查看同步狀態 | `mise bootstrap dotfiles status` |
| 納管檔案 | `mise bootstrap dotfiles track <path>` |
| 解除納管 | `mise bootstrap dotfiles untrack <path>` |
| 安裝 / 移除工具 | `mise install <tool>` / `mise uninstall <tool>` |
| 加入 / 移除全域工具設定 | `mise use -g <tool>` / `mise unuse -g <tool>` |

`install` / `uninstall` 只改變本機已安裝版本；`use` / `unuse` 會修改 mise 設定。
