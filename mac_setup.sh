#!/usr/bin/env bash
# One-shot setup for a bare macOS (Apple Silicon / Intel) machine.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/aryanranderiya/dotfiles/main/mac_setup.sh)
#
# Optional env knobs:
#   DOTFILES_DIR=~/dotfiles   # where the repo lives (default)
#   GAIA_DIR=~/Projects/gaia  # Gaia checkout for the dev-toolchain section ("skip" to skip it)
#   SKIP_BREW=1               # skip Homebrew bundle
#   SKIP_MISE_TOOLS=1         # skip global mise tool installs
#   SKIP_GAIA=1               # skip the Gaia dev-toolchain section
#
# Safe to re-run: every step skips what is already installed.
# Existing ~/.zshrc and Ghostty configs are backed up as <file>.bak.<timestamp>.
set -euo pipefail

DOTFILES_REPO="https://github.com/aryanranderiya/dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
GAIA_DIR="${GAIA_DIR:-$HOME/Projects/gaia}"

log()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn] %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
log "Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
  warn "finish the CLT installer popup, then re-run this script"
  exit 1
fi

# ---------------------------------------------------------------------------
log "Homebrew"
if ! have brew; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi
if [ -z "${SKIP_BREW:-}" ]; then
  brew update
  # git/gh/gnupg are native; thefuck + infisical CLIs only ship via brew here.
  # The zsh aliases (eza, zoxide, gping, procs, duf, fastfetch, atuin, fzf,
  # bat, ripgrep) come from mise below so both macOS and Ubuntu share versions.
  brew install git gh gnupg thefuck infisical/get-cli/infisical 2>/dev/null \
    || brew install git gh gnupg thefuck 2>/dev/null \
    || warn "some brew formulae failed — run 'brew doctor' and re-run"
  if ! have docker; then
    brew install --cask docker 2>/dev/null \
      || warn "Docker Desktop cask needs admin rights — install it from https://docs.docker.com/get-docker/"
  fi
else
  log "SKIP_BREW set, skipping Homebrew bundle"
fi

# ---------------------------------------------------------------------------
log "Dotfiles repo"
if [ ! -d "$DOTFILES_DIR/.git" ]; then
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  git -C "$DOTFILES_DIR" pull --ff-only || warn "could not pull dotfiles, using local copy"
fi

# ---------------------------------------------------------------------------
log "mise + CLI tools"
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
if ! have mise; then
  curl -fsSL https://mise.run | sh
fi
if [ -z "${SKIP_MISE_TOOLS:-}" ]; then
  # Use the gh token (if logged in) to avoid GitHub download rate limits
  if [ -z "${GITHUB_TOKEN:-}" ] && have gh && gh auth status >/dev/null 2>&1; then
    export GITHUB_TOKEN="$(gh auth token)"
  fi
  mise use -g -y \
    node@lts pnpm@latest uv@latest \
    fzf@latest zoxide@latest eza@latest gping@latest \
    github:dalance/procs@latest duf@latest fastfetch@latest atuin@latest \
    bat@latest ripgrep@latest
  mise reshim
else
  log "SKIP_MISE_TOOLS set, skipping global tool installs"
fi

# ---------------------------------------------------------------------------
log "Oh My Zsh + plugins"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
clone_plugin() {
  local name="$1" url="$2"
  if [ -d "$ZSH_CUSTOM/plugins/$name" ]; then
    git -C "$ZSH_CUSTOM/plugins/$name" pull --ff-only -q || true
  else
    git clone --depth 1 "$url" "$ZSH_CUSTOM/plugins/$name"
  fi
}
mkdir -p "$ZSH_CUSTOM/plugins"
clone_plugin zsh-autosuggestions          https://github.com/zsh-users/zsh-autosuggestions
clone_plugin zsh-completions              https://github.com/zsh-users/zsh-completions
clone_plugin zsh-history-substring-search https://github.com/zsh-users/zsh-history-substring-search
clone_plugin fzf-tab                      https://github.com/Aloxaf/fzf-tab
clone_plugin zsh-autocomplete             https://github.com/marlonrichert/zsh-autocomplete

# ---------------------------------------------------------------------------
log "Linking config files"
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak.$(date +%s)"
  fi
  ln -sfn "$src" "$dst"
  echo "  $dst -> $src"
}
link "$DOTFILES_DIR/dot_zshrc"      "$HOME/.zshrc"
# Ghostty on macOS reads the Application Support path; the XDG path covers
# CLI contexts. Both point at the same repo file.
link "$DOTFILES_DIR/ghostty_config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
link "$DOTFILES_DIR/ghostty_config" "$HOME/.config/ghostty/config"
# Ghostty once created an empty config.ghostty placeholder — retire it.
if [ -f "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty" ] \
  && [ ! -s "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty" ]; then
  mv "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty" \
     "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty.bak.$(date +%s)"
fi

# Preserve machine-local shell lines (e.g. ~/.opencode/bin PATH, OrbStack)
# that lived in the pre-dotfiles ~/.zshrc — they are not committed.
LOCAL_FILE="$HOME/.zshrc.local"
touch "$LOCAL_FILE"
for needle in '.opencode/bin' 'orbstack/shell/init.zsh'; do
  for bak in "$HOME"/.zshrc.bak.*; do
    [ -f "$bak" ] || continue
    if grep -q "$needle" "$bak" && ! grep -q "$needle" "$LOCAL_FILE"; then
      grep "$needle" "$bak" >> "$LOCAL_FILE"
      echo "  preserved '$needle' in ~/.zshrc.local"
    fi
  done
done

# ---------------------------------------------------------------------------
log "git identity"
if [ -z "$(git config --global user.name 2>/dev/null || true)" ]; then
  warn "git user.name is unset — run:"
  echo "  git config --global user.name \"Your Name\""
fi
if [ -z "$(git config --global user.email 2>/dev/null || true)" ]; then
  warn "git user.email is unset — run:"
  echo "  git config --global user.email \"you@example.com\""
fi
if have gh; then
  if ! gh auth status >/dev/null 2>&1; then
    warn "gh is not logged in — run: gh auth login"
  fi
  if [ ! -f "$HOME/.ssh/id_ed25519.pub" ] && [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
    warn "no SSH key found — run: ssh-keygen -t ed25519 -C \"you@example.com\" && gh ssh-key add"
  fi
fi

# ---------------------------------------------------------------------------
if [ -z "${SKIP_GAIA:-}" ] && [ -d "$GAIA_DIR" ]; then
  log "Gaia dev toolchain ($GAIA_DIR)"
  mise trust "$GAIA_DIR/mise.toml"
  # Install the repo's pinned tools (python 3.12, node 22, uv, prek, nx, ...)
  ( builtin cd "$GAIA_DIR" && mise install -y )

  # pnpm at the repo-pinned version (packageManager field, e.g. pnpm@10.17.1).
  # The mise-global pnpm is intentionally latest and will drift ahead, so
  # install here through `mise exec pnpm@<pinned>` instead of bare `pnpm`
  # (a wrong major can silently skip patchedDependencies, e.g. dmg-builder).
  export PATH="$HOME/.local/share/mise/shims:$PATH"
  PINNED_PNPM="$(builtin cd "$GAIA_DIR" && node -p "require('./package.json').packageManager" 2>/dev/null || echo pnpm@10.17.1)"
  if have mise; then
    ( builtin cd "$GAIA_DIR" && mise exec "$PINNED_PNPM" -- pnpm install )
  else
    warn "mise still missing — run 'corepack prepare $PINNED_PNPM --activate' manually"
  fi

  # Env files: web/mobile auto-copy from examples, api needs real secrets
  # (team: `mise infisical dev` injects them; else copy the example to boot).
  if [ ! -f "$GAIA_DIR/apps/web/.env" ] && [ -f "$GAIA_DIR/apps/web/.env.example" ]; then
    cp "$GAIA_DIR/apps/web/.env.example" "$GAIA_DIR/apps/web/.env"
    echo "  created apps/web/.env from example"
  fi
  if [ ! -f "$GAIA_DIR/apps/mobile/.env" ] && [ -f "$GAIA_DIR/apps/mobile/.env.example" ]; then
    cp "$GAIA_DIR/apps/mobile/.env.example" "$GAIA_DIR/apps/mobile/.env"
    echo "  created apps/mobile/.env from example"
  fi
  if [ ! -f "$GAIA_DIR/apps/api/.env" ]; then
    warn "apps/api/.env is missing — team members: run 'mise infisical dev' (after 'infisical login'); others: cp apps/api/.env.example apps/api/.env"
  fi

  # Pre-commit hooks (prek, managed by mise)
  ( builtin cd "$GAIA_DIR" && mise run pre-commit:install ) || warn "pre-commit install failed"

  # Infra containers (postgres, mongo, redis, chroma, rabbitmq — infra only,
  # the API itself runs natively via `mise dev`)
  if have docker && docker info >/dev/null 2>&1; then
    ( builtin cd "$GAIA_DIR/infra/docker" && docker compose up -d ) || warn "docker compose up failed"
  else
    warn "Docker is not running — start Docker Desktop, then: (cd $GAIA_DIR/infra/docker && docker compose up -d)"
  fi
elif [ -d "$GAIA_DIR" ]; then
  log "SKIP_GAIA set, skipping Gaia toolchain"
else
  log "No Gaia checkout at $GAIA_DIR, skipping Gaia toolchain"
fi

log "Done! Open a new Ghostty window (config hot-reloads with Cmd+Shift+,), then: gh auth login"
