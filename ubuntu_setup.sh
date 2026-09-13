#!/usr/bin/env bash
# One-shot setup for a bare Ubuntu (24.04+) machine.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/aryanranderiya/dotfiles/main/ubuntu_setup.sh)
#
# Safe to re-run: every step skips what is already installed.
set -euo pipefail

DOTFILES_REPO="https://github.com/aryanranderiya/dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

log()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn] %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

USER="${USER:-$(id -un)}"

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
if [ -n "$SUDO" ]; then
  sudo -v
  # Keep sudo alive until the script finishes
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

export DEBIAN_FRONTEND=noninteractive
ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"

# ---------------------------------------------------------------------------
log "Base apt packages"
$SUDO apt-get update -y
$SUDO apt-get install -y \
  zsh git curl wget ca-certificates gnupg unzip build-essential \
  command-not-found software-properties-common apt-transport-https

# ---------------------------------------------------------------------------
log "Dotfiles repo"
if [ ! -d "$DOTFILES_DIR/.git" ]; then
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  git -C "$DOTFILES_DIR" pull --ff-only || warn "could not pull dotfiles, using local copy"
fi

# ---------------------------------------------------------------------------
log "GitHub CLI"
if ! have gh; then
  $SUDO install -dm 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  $SUDO apt-get update -y
  $SUDO apt-get install -y gh
fi

# ---------------------------------------------------------------------------
log "Docker"
if ! have docker; then
  $SUDO install -dm 755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO tee /etc/apt/keyrings/docker.asc >/dev/null
  $SUDO chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODENAME stable" \
    | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
if [ -n "$SUDO" ] && ! id -nG "$USER" | grep -qw docker; then
  $SUDO usermod -aG docker "$USER"
fi
if have systemctl && [ -d /run/systemd/system ]; then
  $SUDO systemctl enable --now docker || true
fi

# ---------------------------------------------------------------------------
log "ngrok"
if ! have ngrok; then
  curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | $SUDO tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | $SUDO tee /etc/apt/sources.list.d/ngrok.list >/dev/null
  $SUDO apt-get update -y
  $SUDO apt-get install -y ngrok
fi

# ---------------------------------------------------------------------------
log "mise + CLI tools"
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
if ! have mise; then
  curl -fsSL https://mise.run | sh
fi
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

# ---------------------------------------------------------------------------
log "Ghostty"
if ! have ghostty; then
  if have snap && [ -d /run/systemd/system ]; then
    $SUDO snap install ghostty --classic || warn "ghostty snap install failed"
  else
    warn "snap unavailable, skipping Ghostty"
  fi
fi

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
link "$DOTFILES_DIR/ubuntu_zshrc"   "$HOME/.zshrc"
link "$DOTFILES_DIR/ghostty_config" "$HOME/.config/ghostty/config"

# ---------------------------------------------------------------------------
log "Default shell"
ZSH_BIN="$(command -v zsh)"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$ZSH_BIN" ]; then
  $SUDO chsh -s "$ZSH_BIN" "$USER" || warn "chsh failed, run: chsh -s $ZSH_BIN"
fi

log "Done! Log out and back in (for zsh + docker group), then run: gh auth login"
