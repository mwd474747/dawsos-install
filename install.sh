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

INSTALLER_VERSION="install-v1.0.47"
ENGINE_BUNDLE_TAG="dawsos-bundle-src-20260308-024733Z"
ENGINE_ASSET="dawsos-engine-9643df9.tar.gz"
ENGINE_SHA256_ASSET="dawsos-engine-9643df9.tar.gz.sha256"

ENGINE_URL="https://github.com/mwd474747/dawsos-install/releases/download/${ENGINE_BUNDLE_TAG}/${ENGINE_ASSET}"
ENGINE_SHA256_URL="https://github.com/mwd474747/dawsos-install/releases/download/${ENGINE_BUNDLE_TAG}/${ENGINE_SHA256_ASSET}"

WS="${WS:-$HOME/.openclaw/workspace}"
BUNDLES_DIR="$WS/engine-bundles"
ENGINE_BUNDLE_DIR="$BUNDLES_DIR/$ENGINE_BUNDLE_TAG"
ACTIVE_LINK="$BUNDLES_DIR/active"
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

# Extract into a temp dir, then move the single top-level folder into ENGINE_BUNDLE_DIR.
EXTRACT_DIR="$BUNDLES_DIR/.extract-$ENGINE_BUNDLE_TAG"
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$TMP" -C "$EXTRACT_DIR"

# Expect exactly one top-level directory.
TOP_COUNT="$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[ "$TOP_COUNT" = "1" ] || die "Unexpected bundle layout (expected 1 top-level dir, got $TOP_COUNT)"
TOP_DIR="$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

mv "$TOP_DIR" "$ENGINE_BUNDLE_DIR"
rm -rf "$EXTRACT_DIR"

# Stamp bundle manifest with bundle_id + installer metadata (best-effort)
if [ -f "$ENGINE_BUNDLE_DIR/bundle-manifest.json" ]; then
  python3 - <<PY || true
import json
from pathlib import Path
p=Path(r"$ENGINE_BUNDLE_DIR")/"bundle-manifest.json"
try:
    d=json.loads(p.read_text(encoding='utf-8'))
    d['bundle_id']=r"$ENGINE_BUNDLE_TAG"
    d['bundle_tag']=r"$ENGINE_BUNDLE_TAG"
    # Engine asset filenames are commit-pinned (dawsos-engine-<sha>.tar.gz)
    d['engine_commit']=r"$ENGINE_ASSET".replace('dawsos-engine-','').replace('.tar.gz','')
    d['installer_version']=r"$INSTALLER_VERSION"
    p.write_text(json.dumps(d, indent=2)+"\n", encoding='utf-8')
except Exception:
    pass
PY
fi

log "5/7 Set active bundle pointer"
rm -rf "$ACTIVE_LINK"
ln -s "$ENGINE_BUNDLE_DIR" "$ACTIVE_LINK"

# Write an explicit marker to eliminate guesswork when debugging.
ACTIVE_JSON="$BUNDLES_DIR/ACTIVE.json"
python3 - <<PY || true
import json
from datetime import datetime, timezone
from pathlib import Path
p=Path(r"$ENGINE_BUNDLE_DIR")/"bundle-manifest.json"
manifest={}
try:
    if p.exists():
        manifest=json.loads(p.read_text(encoding='utf-8'))
except Exception:
    manifest={}
out={
  "installed_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z'),
  "installer_version": r"$INSTALLER_VERSION",
  "engine_bundle_tag": r"$ENGINE_BUNDLE_TAG",
  "engine_bundle_dir": r"$ENGINE_BUNDLE_DIR",
  "bundle_manifest": {
    "bundle_id": manifest.get("bundle_id"),
    "bundle_tag": manifest.get("bundle_tag") or manifest.get("tag") or manifest.get("id"),
    "engine_commit": manifest.get("engine_commit") or manifest.get("commit"),
  },
}
Path(r"$ACTIVE_JSON").write_text(json.dumps(out,indent=2)+"\n",encoding='utf-8')
print("WROTE", r"$ACTIVE_JSON")
PY

log "6/8 Point workspace engine symlink at active"
rm -rf "$ENGINE_DIR"
ln -s "$ACTIVE_LINK" "$ENGINE_DIR"

log "7/8 Legacy-compat symlink: dawsco-engine (OFF by default)"
# Aggressive posture: disable legacy compat by default to surface breakage quickly.
# Opt-in by setting: DAWSOS_ENABLE_DAWSCO_ENGINE_COMPAT=1
if [ "${DAWSOS_ENABLE_DAWSCO_ENGINE_COMPAT:-}" = "1" ]; then
  rm -rf "$WS/dawsco-engine"
  ln -s "$ENGINE_DIR" "$WS/dawsco-engine"
  log "compat: enabled ($WS/dawsco-engine -> $ENGINE_DIR)"
else
  log "compat: disabled (set DAWSOS_ENABLE_DAWSCO_ENGINE_COMPAT=1 to enable)"
fi

log "8/10 Seed cron jobs (authoritative for dawsos-*)"
(
  cd "$ENGINE_DIR"
  python3 scripts/ops/dawsos_cron_seed.py --authoritative >/dev/null 2>&1
) || {
  echo "WARN: cron seed failed (non-fatal)." >&2
  (cd "$ENGINE_DIR" && python3 scripts/ops/dawsos_cron_seed.py --authoritative >&2) || true
}

log "9/10 Ensure Node.js + OpenClaw"

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

log "10/10 Validate bundle manifest + run wizard"
cd "$ENGINE_DIR"

# Write an explicit bootstrap receipt (control-surface friendly)
OPS_DIR="$WS/reports/ops"
mkdir -p "$OPS_DIR"
RECEIPT="$OPS_DIR/partner-install-artifact-bootstrap-receipt-latest.json"
cat > "$RECEIPT" <<JSON
{
  "kind": "receipt",
  "schema_version": "0.2.0",
  "name": "partner_install_artifact_bootstrap",
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
  "engine_bundle_dir": "${ENGINE_BUNDLE_DIR}",
  "active_link": "${ACTIVE_LINK}"
}
JSON

# Validate bundle manifest before running (catches bad extractions early)
python3 scripts/ops/bundle_manifest_validate.py >/dev/null 2>&1 || {
  echo "ERROR: bundle-manifest validation failed." >&2
  python3 scripts/ops/bundle_manifest_validate.py >&2 || true
  exit 1
}

# Only forward arguments if explicitly provided (avoid passing stray 'bash' when piped)
if [ "$#" -gt 0 ]; then
  python3 scripts/install/partner_install_wizard.py "$@"
else
  python3 scripts/install/partner_install_wizard.py
fi

# --- Post-install: PR-lane readiness preflight (best-effort) ---
# Rationale: PR-lane capability is node-local (git remote + fetch + identity + provider auth).
# This installer runs in artifact mode and avoids git/gh requirements for core install, so
# we record readiness separately as an observation receipt.
log "Post-install: PR-lane readiness preflight (best-effort)"
python3 - <<'PY' || echo "WARN: PR-lane readiness preflight failed (non-fatal)." >&2
import json, os, subprocess, time
from datetime import datetime, timezone
from pathlib import Path

def iso_now():
  return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z')

def run(cmd, cwd, timeout=20):
  p = subprocess.run(cmd, cwd=str(cwd), text=True, capture_output=True, timeout=timeout)
  return p.returncode, (p.stdout or '').strip(), (p.stderr or '').strip()

ws = Path(os.environ.get('WS') or (Path.home()/'.openclaw'/'workspace')).resolve()
ops = ws/'reports'/'ops'
ops.mkdir(parents=True, exist_ok=True)
state_p = ops/'git-pr-lane-readiness-state-latest.json'
rcpt_p = ops/'git-pr-lane-readiness-receipt-latest.json'

node_id = os.environ.get('DAWSOS_NODE_ID') or os.environ.get('NODE_ID') or 'mbp'
checks=[]
warnings=[]
errors=[]

# git repo present
if (ws/'.git').exists():
  checks.append({'check_id':'git_repo_present','status':'pass','detail':'workspace has .git','evidence':{'path':str(ws/'.git')}})
else:
  checks.append({'check_id':'git_repo_present','status':'warn','detail':'workspace missing .git (artifact installs may be non-git)','evidence':{'path':str(ws/'.git')}})
  warnings.append('missing_git_repo')

# origin remote
origin_url=None
rc,out,err = run(['git','remote','get-url','origin'], cwd=ws, timeout=5)
if rc==0 and out:
  origin_url=out
  checks.append({'check_id':'git_origin_present','status':'pass','detail':'origin configured','evidence':{'origin_url':origin_url}})
else:
  checks.append({'check_id':'git_origin_present','status':'warn','detail':'origin missing (PR-lane blocked)','evidence':{'stderr':err}})
  warnings.append('missing_origin_remote')

# fetch dry-run
if origin_url:
  rc,out,err = run(['git','fetch','--dry-run','origin'], cwd=ws, timeout=20)
  if rc==0:
    checks.append({'check_id':'git_fetch_origin_dry_run','status':'pass','detail':'fetch ok','evidence':{}})
  else:
    checks.append({'check_id':'git_fetch_origin_dry_run','status':'warn','detail':'fetch failed (PR-lane blocked)','evidence':{'stderr':err}})
    warnings.append('origin_fetch_failed')

# identity
rc,name,_ = run(['git','config','--get','user.name'], cwd=ws, timeout=5)
rc2,email,_ = run(['git','config','--get','user.email'], cwd=ws, timeout=5)
name=name.strip() if rc==0 else ''
email=email.strip() if rc2==0 else ''
if name and email:
  checks.append({'check_id':'git_identity_configured','status':'pass','detail':'git identity set','evidence':{'user.name':name,'user.email':email}})
else:
  checks.append({'check_id':'git_identity_configured','status':'warn','detail':'git identity missing (PR-lane blocked)','evidence':{'user.name':name or None,'user.email':email or None}})
  warnings.append('missing_git_identity')

# provider auth (gh)
rc,out,err = run(['gh','auth','status'], cwd=ws, timeout=10)
if rc==0:
  checks.append({'check_id':'provider_auth','status':'pass','detail':'gh auth ok','evidence':{'summary':out.splitlines()[:6]}})
else:
  checks.append({'check_id':'provider_auth','status':'warn','detail':'gh auth missing (PR-lane blocked)','evidence':{'stderr':err or out}})
  warnings.append('missing_provider_auth')

# status
status = 'pass' if not warnings and not errors else ('warn' if not errors else 'fail')
state={
  'kind':'git_pr_lane_readiness.v0',
  'schema_version':'0.1.0',
  'generated_at': iso_now(),
  'node_id': node_id,
  'status': status,
  'checks': checks,
  'warnings': warnings,
  'errors': errors,
}
state_p.write_text(json.dumps(state, indent=2)+'\n', encoding='utf-8')
receipt={
  'kind':'receipt',
  'schema_version':'0.2.0',
  'ts': iso_now(),
  'name':'git_pr_lane_readiness_check',
  'status': status,
  'summary': f"status={status} warnings={len(warnings)} errors={len(errors)}",
  'warnings': warnings,
  'errors': errors,
  'artifacts': [str(state_p), str(rcpt_p)],
}
rcpt_p.write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
print(receipt['summary'])
PY
