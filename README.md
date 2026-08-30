# dotfiles

## 安裝

安裝 [mise](https://mise.jdx.dev/)：
```bash
curl https://mise.run | sh
```

安裝 dotfiles：
```bash
git clone https://github.com/Elliot-32/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
~/.local/bin/mise trust --all
~/.local/bin/mise bootstrap --yes --force-dotfiles && exec zsh -l
```

第一次安裝時，bootstrap 會執行 `gh auth login` 與 `gh auth setup-git`，
並詢問 Git user name 與 email。這些設定由 Git 與 GitHub CLI 寫入本機，
不會納入 dotfiles。非互動環境可預先設定 `GIT_USER_NAME` 與
`GIT_USER_EMAIL`。

需要 mise 2026.8.13 以上版本。`.miserc.toml` 只依發行版標記檔選擇
`apt`、`dnf` 或 `pacman` 設定，不會因為系統上碰巧裝有其他套件管理器
就載入它。Ubuntu 系列需同時有 `/etc/lsb-release` 與 Ubuntu archive
keyring（包含 Pop!_OS）；偵測到圖形桌面 session 目錄時，才會另外載入
根目錄的 `mise.flatpak.toml`。

## 日常使用

檢查目前狀態：

```bash
mise bootstrap status
```

查看目前納管的 dotfiles：

```bash
mise bootstrap dotfiles status
```

納管新的 dotfile：

```bash
mise bootstrap dotfiles add ~/.config/example/config
```

解除納管 dotfile：

```bash
mise bootstrap dotfiles unapply ~/.config/example/config
```

接著從 `~/.config/mise/config.toml` 的 `[dotfiles]` 移除對應項目，並刪除 repo 內對應的 source，例如：

```bash
rm ~/.dotfiles/.config/example/config
```

`unapply` 只會解除部署，不會修改 `[dotfiles]` 或刪除 repo 內的 source。

新增或修改全域工具時：

```bash
mise use -g <tool>
```
或直接編輯 `~/.config/mise/config.toml`

更新 mise 管理的工具、Sheldon plugins 與 shell completions：

```bash
mise run update
```

所有納管的 dotfiles 預設都以 symlink 方式部署，因此直接修改家目錄中的檔案，就會同步修改 repo 內對應的檔案。

套用所有變更：

```bash
mise bootstrap --yes --force-dotfiles
```

或者只套用 dotfiles 不執行 bootstrap：

```bash
mise bootstrap dotfiles apply --force --yes
```
