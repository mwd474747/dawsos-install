# dawsos-install

Public installer entrypoint for DawsOS installs.

- This repo contains **no secrets**.
- It installs from a **public release artifact** (no GitHub login required).
- Docker pulls still occur as part of runtime setup.

## Andrew v1 (fresh Mac, Docker required)

### One command

```bash
# Recommended (immutable tag; avoids cache issues)
curl -fsSL https://raw.githubusercontent.com/mwd474747/dawsos-install/install-v1.0.19/install.sh | bash
```

(Dev only / may be cached):
```bash
curl -fsSL https://raw.githubusercontent.com/mwd474747/dawsos-install/main/install.sh | bash
```

Dry-run (diagnostic):
```bash
curl -fsSL https://raw.githubusercontent.com/mwd474747/dawsos-install/install-v1.0.19/install.sh | bash -s -- --dry-run
```

What it does:
- downloads a **pinned public engine bundle** from GitHub Releases
- verifies SHA256
- extracts into `~/.openclaw/workspace/dawsos-engine`
- verifies Docker Desktop is installed + running
- ensures Node.js + OpenClaw are installed
- launches the install wizard

What it avoids:
- `gh auth login`
- `git clone` of private repos

Fallback: see `INSTALL_ANDREW_V1.md` (fully inlined) and `TROUBLESHOOT_GIT.md`.

This repo is intentionally thin: it bootstraps `dawsos-engine` at a pinned tag/commit and launches the TUI wizard.
