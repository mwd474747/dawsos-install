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

TAG="andrew-v1-dbdb270"
ASSET="dawsos-engine-dbdb270.tar.gz"
URL="https://github.com/mwd474747/dawsos-install/releases/download/${TAG}/${ASSET}"

WS="${WS:-$HOME/.openclaw/workspace}"
ENGINE_DIR="$WS/dawsos-engine"
TMP="/tmp/$ASSET"

log() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

if [ "$(id -u)" -eq 0 ]; then
  die "Do not run this installer as root. Open a normal Terminal and rerun."
fi

log "DawsOS install (artifact mode): $TAG"

log "0/4 Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  log "CLT missing; running xcode-select --install"
  xcode-select --install || true
  die "Re-run after CLT finishes installing."
fi

log "1/4 Docker (required)"
command -v docker >/dev/null 2>&1 || die "docker CLI not found. Install Docker Desktop first."
docker info >/dev/null 2>&1 || die "Docker Desktop not running. Start it first."

log "2/4 Download engine bundle"
mkdir -p "$WS"
curl -fL --retry 3 --retry-delay 2 "$URL" -o "$TMP" || die "Failed to download $URL"

log "3/4 Extract + run wizard"
rm -rf "$ENGINE_DIR"
mkdir -p "$ENGINE_DIR"
# Artifact contains top-level folder dawsos-engine-dbdb270/
tar -xzf "$TMP" -C "$WS"
# Normalize folder name
rm -rf "$ENGINE_DIR"
mv "$WS/dawsos-engine-dbdb270" "$ENGINE_DIR"

cd "$ENGINE_DIR"
python3 scripts/install/andrew_install_wizard.py
