# Andrew Install v1 (fresh macOS)

This installs **DawsOS** from the canonical private engine repo and launches the installer wizard.

## Prereqs
- You have accepted the GitHub invite to the private repos.
- Docker Desktop installed and running.

## One command (copy/paste)

```bash
WS="$HOME/.openclaw/workspace" ENGINE_URL="https://github.com/mwd474747/dawsos-engine.git" ENGINE_REF="dbdb270" /bin/bash -euo pipefail <<'SH'
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: Do not run this installer as root. Open a normal Terminal and rerun." >&2
  exit 1
fi

echo "== DawsOS Andrew Install v1 (private) =="

# 0) Xcode CLT
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools missing. Running: xcode-select --install"
  xcode-select --install || true
  echo "Re-run this same command after CLT finishes installing." >&2
  exit 1
fi

# helper: load brew into PATH
brew_shellenv() {
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; return 0; fi
  if [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; return 0; fi
  return 1
}

# 1) Homebrew
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew missing."
  read -r -p "Install Homebrew now? [y/N] " yn
  [[ "$yn" =~ ^[Yy]$ ]] || { echo "Aborting."; exit 1; }
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew_shellenv || { echo "ERROR: brew installed but not found. Open a NEW Terminal and rerun." >&2; exit 1; }
else
  brew_shellenv || true
fi

# 2) GitHub CLI auth (private repo)
if ! command -v gh >/dev/null 2>&1; then
  brew install gh
fi
if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "Starting GitHub login. Choose: GitHub.com → HTTPS → Login with a web browser."
  gh auth login -h github.com -p https -w
fi

gh auth setup-git || true

# 3) Docker (required)
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker CLI not found. Install Docker Desktop first." >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "ERROR: Docker Desktop not running. Start it first." >&2; exit 1; }

# 4) Clone engine at pinned ref
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

# 5) Run wizard
python3 dawsco-engine/scripts/install/andrew_install_wizard.py
SH
```

## Notes
- This pins to `ENGINE_REF=dbdb270` (known-good installer wizard + contract). You can later update to a release tag.
- Docker is required.
- No secrets are set.
