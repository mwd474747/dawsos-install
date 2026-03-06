#!/usr/bin/env bash
set -euo pipefail

WS="${WS:-$HOME/.openclaw/workspace}"
ENGINE_URL="${ENGINE_URL:-https://github.com/mwd474747/dawsos-engine.git}"
ENGINE_REF="${ENGINE_REF:-dbdb270}"

log() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

die() { echo "ERROR: $*" >&2; exit 1; }

if [ "$(id -u)" -eq 0 ]; then
  die "Do not run this installer as root. Open a normal Terminal and rerun."
fi

log "DawsOS Install (Andrew v1, private, Docker required)"

log "0/7 Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  log "CLT missing; running xcode-select --install"
  xcode-select --install || true
  die "Re-run after CLT finishes installing."
fi

brew_shellenv() {
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; return 0; fi
  if [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; return 0; fi
  return 1
}

log "1/7 Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew missing."
  read -r -p "Install Homebrew now? [y/N] " yn
  [[ "$yn" =~ ^[Yy]$ ]] || die "Aborting."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew_shellenv || die "brew installed but not found. Open a NEW Terminal and rerun."
else
  brew_shellenv || true
fi

log "2/7 GitHub CLI"
if ! command -v gh >/dev/null 2>&1; then
  brew install gh
fi

log "3/7 GitHub login (device/browser flow)"
if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "Choose: GitHub.com → HTTPS → Login with a web browser."
  gh auth login -h github.com -p https -w
fi

gh auth setup-git || true

log "4/7 Prove private repo access"
if ! gh repo view mwd474747/dawsos-engine --json name,viewerPermission >/dev/null 2>&1; then
  echo "You are logged into GitHub but do not have access to the private repo yet." >&2
  echo "- Accept the invite, and ensure you're logged into the invited account." >&2
  echo "- If needed: gh auth logout -h github.com" >&2
  exit 1
fi

log "5/7 Docker (required)"
command -v docker >/dev/null 2>&1 || die "docker CLI not found. Install Docker Desktop first."
docker info >/dev/null 2>&1 || die "Docker Desktop not running. Start it first."

log "6/7 Clone engine + launch wizard"
mkdir -p "$WS"
cd "$WS"
if [ -d "$WS/dawsos-engine/.git" ]; then
  cd "$WS/dawsos-engine"
  git fetch --all --prune
  git checkout "$ENGINE_REF"
else
  git clone "$ENGINE_URL" "$WS/dawsos-engine"
  cd "$WS/dawsos-engine"
  git checkout "$ENGINE_REF"
fi

python3 scripts/install/andrew_install_wizard.py
