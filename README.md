# dotfiles

## Ubuntu setup (one shot)

On a bare Ubuntu 24.04+ machine, run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/aryanranderiya/dotfiles/main/ubuntu_setup.sh)
```

Safe to re-run — anything already installed is skipped.

### What it installs

- **apt:** zsh, git, build-essential, gh, Docker (adds you to the `docker` group), ngrok
- **mise:** node, pnpm, uv, fzf, zoxide, eza, gping, procs, duf, fastfetch, atuin, bat, ripgrep
- **Shell:** Oh My Zsh + zsh-autosuggestions, zsh-completions, zsh-history-substring-search, fzf-tab
- **Terminal:** Ghostty (snap)

### What it links

| Repo file        | Linked to                     |
| ---------------- | ----------------------------- |
| `ubuntu_zshrc`   | `~/.zshrc`                    |
| `ghostty_config` | `~/.config/ghostty/config`    |

Existing files are backed up as `<file>.bak.<timestamp>`. zsh is set as the default shell.

### After running

1. Log out and back in (for zsh + docker group).
2. `gh auth login`
3. Set your git identity:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```

## macOS

- `dot_zshrc` — zsh config
- `.macos` — system defaults (`bash .macos`)
- `ghostty_config` — Ghostty config
