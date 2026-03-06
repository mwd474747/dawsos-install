# dawsos-install

Private installer entrypoint for DawsOS partner installs.

## Andrew v1 (fresh Mac, Docker required)

Preferred single-command entrypoint (requires GitHub CLI login for private repos):

```bash
/bin/bash -lc 'set -euo pipefail; WS="$HOME/.openclaw/workspace"; mkdir -p "$WS"; cd "$WS"; if ! command -v gh >/dev/null 2>&1; then echo "GitHub CLI (gh) is required. Install via Homebrew first."; exit 1; fi; if ! gh auth status -h github.com >/dev/null 2>&1; then echo "Logging into GitHub (device/browser flow)..."; gh auth login -h github.com -p https -w; fi; gh auth setup-git || true; gh api -H "Accept: application/vnd.github.raw" /repos/mwd474747/dawsos-install/contents/bootstrap_andrew_v1.sh > /tmp/bootstrap_andrew_v1.sh; chmod +x /tmp/bootstrap_andrew_v1.sh; /tmp/bootstrap_andrew_v1.sh'
```

Fallback: see `INSTALL_ANDREW_V1.md` for the fully inlined script.

This repo is intentionally thin: it bootstraps `dawsos-engine` at a pinned tag/commit and launches the TUI wizard.
