#!/usr/bin/env bash
set -euo pipefail

# DawsOS public bootstrapper.
#
# Goal: one-command install that does NOT require private GitHub repo access.
#
# How:
# - downloads a PUBLIC release artifact containing a pinned bundle of dawsos-engine
# - extracts it into ~/.openclaw/workspace/dawsos-engine
# - runs the installer wizard
#
# Notes:
# - This repo contains NO secrets.
# - Docker is still required.
# - This flow avoids `gh auth login` + `git clone` entirely.

INSTALLER_VERSION="install-v1.0.1"
ENGINE_BUNDLE_TAG="andrew-v1-dbdb270"
ENGINE_ASSET="dawsos-engine-dbdb270.tar.gz"
ENGINE_SHA256_ASSET="dawsos-engine-dbdb270.tar.gz.sha256"

ENGINE_URL="https://github.com/mwd474747/dawsos-install/releases/download/${ENGINE_BUNDLE_TAG}/${ENGINE_ASSET}"
ENGINE_SHA256_URL="https://github.com/mwd474747/dawsos-install/releases/download/${ENGINE_BUNDLE_TAG}/${ENGINE_SHA256_ASSET}"

WS="${WS:-$HOME/.openclaw/workspace}"
BUNDLES_DIR="$WS/engine-bundles"
ENGINE_BUNDLE_DIR="$BUNDLES_DIR/$ENGINE_BUNDLE_TAG"
ENGINE_DIR="$WS/dawsos-engine"
TMP="/tmp/$ENGINE_ASSET"
TMP_SHA="/tmp/$ENGINE_SHA256_ASSET"

log() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

if [ "$(id -u)" -eq 0 ]; then
  die "Do not run this installer as root. Open a normal Terminal and rerun."
fi

log "DawsOS install (artifact mode)"
log "  installer: $INSTALLER_VERSION"
log "  engine_bundle: $ENGINE_BUNDLE_TAG"

log "0/4 Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  log "CLT missing; running xcode-select --install"
  xcode-select --install || true
  die "Re-run after CLT finishes installing."
fi

log "1/4 Docker (required)"
command -v docker >/dev/null 2>&1 || die "docker CLI not found. Install Docker Desktop first."
docker info >/dev/null 2>&1 || die "Docker Desktop not running. Start it first."

log "2/7 Download engine bundle + sha256"
mkdir -p "$WS" "$BUNDLES_DIR"

curl -fL --retry 3 --retry-delay 2 "$ENGINE_URL" -o "$TMP" || die "Failed to download $ENGINE_URL"
curl -fL --retry 3 --retry-delay 2 "$ENGINE_SHA256_URL" -o "$TMP_SHA" || die "Failed to download $ENGINE_SHA256_URL"

log "3/7 Verify checksum"
EXPECTED="$(awk '{print $1}' "$TMP_SHA" | head -n 1)"
[ -n "$EXPECTED" ] || die "Empty SHA256 file"

if command -v shasum >/dev/null 2>&1; then
  GOT="$(shasum -a 256 "$TMP" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
  GOT="$(sha256sum "$TMP" | awk '{print $1}')"
else
  die "No SHA256 tool found (shasum/sha256sum)."
fi
[ "$GOT" = "$EXPECTED" ] || die "SHA256 mismatch for $ENGINE_ASSET"

log "4/7 Extract bundle (versioned)"
rm -rf "$ENGINE_BUNDLE_DIR"
mkdir -p "$ENGINE_BUNDLE_DIR"
# Artifact contains top-level folder dawsos-engine-dbdb270/
tar -xzf "$TMP" -C "$BUNDLES_DIR"
# Normalize folder name inside bundle dir
rm -rf "$ENGINE_BUNDLE_DIR"
mv "$BUNDLES_DIR/dawsos-engine-dbdb270" "$ENGINE_BUNDLE_DIR"

log "5/8 Point workspace at bundle (symlink)"
rm -rf "$ENGINE_DIR"
ln -s "$ENGINE_BUNDLE_DIR" "$ENGINE_DIR"

# Compatibility: the wizard/stages reference a workspace-local `dawsco-engine/` path.
# In artifact mode, the engine bundle lives under `dawsos-engine/`.
log "6/8 Create workspace compatibility symlink (dawsco-engine)"
rm -rf "$WS/dawsco-engine"
ln -s "$ENGINE_DIR/dawsco-engine" "$WS/dawsco-engine"

log "7/8 Ensure Node.js + OpenClaw"

brew_shellenv() {
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; return 0; fi
  if [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; return 0; fi
  return 1
}

ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    brew_shellenv || true
    return 0
  fi
  echo "Homebrew missing." >&2
  read -r -p "Install Homebrew now? [y/N] " yn
  [[ "$yn" =~ ^[Yy]$ ]] || die "Aborting."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew_shellenv || die "brew installed but not found. Open a NEW Terminal and rerun."
}

if ! command -v node >/dev/null 2>&1; then
  ensure_brew
  log "Installing Node.js (required for OpenClaw)"
  brew install node
fi

if ! command -v openclaw >/dev/null 2>&1; then
  log "Installing OpenClaw (npm global)"
  npm install -g openclaw
fi

log "8/8 Run wizard"
cd "$ENGINE_DIR"

# Write an explicit bootstrap receipt (control-surface friendly)
OPS_DIR="$WS/reports/ops"
mkdir -p "$OPS_DIR"
RECEIPT="$OPS_DIR/andrew-install-artifact-bootstrap-receipt-latest.json"
cat > "$RECEIPT" <<JSON
{
  "kind": "receipt",
  "schema_version": "0.2.0",
  "name": "andrew_install_artifact_bootstrap",
  "status": "pass",
  "installer_version": "${INSTALLER_VERSION}",
  "engine_bundle_tag": "${ENGINE_BUNDLE_TAG}",
  "engine_asset": "${ENGINE_ASSET}",
  "engine_url": "${ENGINE_URL}",
  "engine_sha256_url": "${ENGINE_SHA256_URL}",
  "engine_sha256_expected": "${EXPECTED}",
  "engine_sha256_got": "${GOT}",
  "workspace": "${WS}",
  "engine_dir": "${ENGINE_DIR}",
  "engine_bundle_dir": "${ENGINE_BUNDLE_DIR}"
}
JSON

# Only forward arguments if explicitly provided (avoid passing stray 'bash' when piped)
if [ "$#" -gt 0 ]; then
  python3 scripts/install/andrew_install_wizard.py "$@"
else
  python3 scripts/install/andrew_install_wizard.py
fi
