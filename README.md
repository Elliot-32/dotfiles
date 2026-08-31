# dotfiles

使用 mise 管理開發工具、系統套件與 dotfiles。

## 安裝

需要 [mise](https://mise.jdx.dev/) 2026.8.13 以上版本：

```bash
curl https://mise.run | sh
git clone https://github.com/Elliot-32/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
~/.local/bin/mise trust --all
~/.local/bin/mise bootstrap --yes --force-dotfiles && exec zsh -l
```

## 常用指令

| 用途 | 指令 |
| --- | --- |
| 檢查狀態 | `mise bootstrap status` |
| 更新工具與 plugins | `mise run update` |
| 套用所有變更 | `mise bootstrap --yes --force-dotfiles` |
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

`install` / `uninstall` 只處理本機已安裝的工具版本，不會修改 mise 設定；`use` 會安裝工具並寫入設定，`unuse` 則會從設定中移除工具，並預設清理不再被其他設定使用的版本。

Dotfiles 預設以 symlink 部署。`unapply` 不會修改 `[dotfiles]` 或刪除 repo 內的檔案。
