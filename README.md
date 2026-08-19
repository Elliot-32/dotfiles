# dotfiles

以 [chezmoi](https://www.chezmoi.io/) 管理的個人 dotfiles。

## 管理內容

- `.zshrc` / `.p10k.zsh` — zsh + Powerlevel10k 提示主題
- `.config/zsh/` — zsh 主要設定（config、path、function、completions）
- `.bashrc` / `.bash-preexec.sh` / `.profile`
- `.gitconfig`
- `.config/ghostty/` — Ghostty 終端機設定（含 dracula 主題）
- `.config/fcitx5/` — fcitx5 輸入法設定（不含自動產生的 cached_layouts 快取）

## 在新機器上還原

已安裝 chezmoi 的話：

```bash
chezmoi init --apply Elliot-32
```

尚未安裝 chezmoi 的話，一行裝好並直接套用：

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply Elliot-32
```

> 注意：此 repo 為 private，新機器需先完成 GitHub 認證
> （`gh auth login` 或設定 SSH key）才能 clone。

## 日常使用

```bash
chezmoi add ~/.tmux.conf   # 納管新檔案
chezmoi re-add             # 把家目錄的變更同步回 source
chezmoi edit ~/.zshrc      # 直接編輯 source 版本
chezmoi diff               # 檢視家目錄與 source 的差異
chezmoi apply              # 套用 source 到家目錄
chezmoi update             # 從 GitHub 拉取並套用（多台機器同步用）
```

## 推送變更

```bash
chezmoi cd
git add -A && git commit && git push
```
