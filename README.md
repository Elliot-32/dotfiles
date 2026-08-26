# dotfiles

以 [mise](https://mise.jdx.dev/) 的 `mise bootstrap` 管理個人環境與 dotfiles。

## 管理內容

- `mise.toml` — tools、環境變數、shell aliases、dotfiles、systemd user units
- `.zshrc` / `.p10k.zsh` — zsh + Powerlevel10k
- `.config/sheldon/plugins.toml` — zsh plugins
- `.config/ghostty/config` — Ghostty
- `.config/fcitx5/profile` — fcitx5
- `.config/environment.d/90-fcitx5.conf` — fcitx5 IM 環境變數
- `.gitconfig`
- `.profile`

repo 本身就是 mise 預設的 `dotfiles.root`（`~/.dotfiles`），因此大部分 `[dotfiles]` 項目不需要另外指定 source。`~/.config/mise/config.toml` 會由 mise symlink 到 `~/.dotfiles/mise.toml`，同一份設定同時作為 bootstrap config 與全域 mise config。

## 新機器還原

先安裝 mise：

```bash
curl https://mise.run | sh
```

此 repo 為 private，先準備好可存取 GitHub 的 SSH key，接著：

```bash
git clone git@github.com:Elliot-32/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
~/.local/bin/mise trust
~/.local/bin/mise bootstrap --yes --force-dotfiles
```

`--force-dotfiles` 會取代既有的同名 dotfiles；第一次從 chezmoi 遷移或新系統已有預設 rc 檔時需要使用。

## 日常使用

檢查目前狀態：

```bash
mise bootstrap status
```

修改 dotfile：

```bash
mise bootstrap dotfiles edit ~/.zshrc
mise bootstrap dotfiles apply --yes
```

納管新的 dotfile：

```bash
mise bootstrap dotfiles add ~/.config/example/config
```

新增或修改全域工具時：

```bash
mise use -g <tool>
```

全域 mise config 是 repo 內 `mise.toml` 的 symlink，因此 `mise use -g` 會直接更新 repo 裡的設定。

套用所有變更：

```bash
cd ~/.dotfiles
mise bootstrap --yes
```

同步 Git：

```bash
cd ~/.dotfiles
git pull
mise bootstrap --yes
git add -A && git commit && git push
```
