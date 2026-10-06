# dotfiles

## macOS setup (one shot)

On a bare Mac, run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/aryanranderiya/dotfiles/main/mac_setup.sh)
```

Safe to re-run — anything already installed is skipped. Set `SKIP_GAIA=1` to skip
the Gaia dev-toolchain section, or `GAIA_DIR=~/path/to/gaia` to point at your checkout.

### What it installs

- **Xcode CLT** (prompts once if missing), **Homebrew** (if missing)
- **brew:** git, gh, gnupg, thefuck, infisical, Docker Desktop (cask, best-effort)
- **mise:** node, pnpm, uv, fzf, zoxide, eza, gping, procs, duf, fastfetch, atuin, bat, ripgrep
- **Shell:** Oh My Zsh + zsh-autosuggestions, zsh-completions, zsh-history-substring-search, fzf-tab, zsh-autocomplete
- **Gaia (if `~/Projects/gaia` exists):** pinned mise tools, `pnpm install`, `.env` files from examples, prek hooks, `docker compose up -d` (infra only)

### What it links

| Repo file        | Linked to                                            |
| ---------------- | ---------------------------------------------------- |
| `dot_zshrc`      | `~/.zshrc`                                           |
| `ghostty_config` | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| `ghostty_config` | `~/.config/ghostty/config`                           |

Existing files are backed up as `<file>.bak.<timestamp>`. Pre-dotfiles shell lines
(e.g. `~/.opencode/bin` PATH, OrbStack init) are preserved in `~/.zshrc.local`,
which `dot_zshrc` sources. Machine-local overrides go there — never in the repo.

`dot_zshrc` also fixes two sharp edges: mise is activated on PATH (was missing),
and the `fastfetch` / `atuin` / `thefuck` / `fzf` tail is guarded with `command -v`
so a fresh shell never fails when a tool is absent.

### After running

1. Open a new Ghostty window (or reload config).
2. `gh auth login`
3. Set your git identity (the script warns if unset):
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```
4. Gaia: `infisical login` once, then `mise infisical dev` for secrets-backed runs.

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
