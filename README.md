# dawsos-install

Public installer entrypoint for DawsOS installs.

- This repo contains **no secrets**.
- It bootstraps access to the private engine repo (`mwd474747/dawsos-engine`) via GitHub CLI device/browser login.

## Andrew v1 (fresh Mac, Docker required)

### One command

```bash
curl -fsSL https://raw.githubusercontent.com/mwd474747/dawsos-install/main/install.sh | bash
```

What it does:
- downloads `bootstrap_andrew_v1.sh` (no secrets)
- installs prerequisites (Xcode CLT, Homebrew, gh)
- performs GitHub device/browser login to access private `mwd474747/dawsos-engine`
- validates access before cloning (so it won’t hang at git)
- verifies Docker Desktop is installed + running
- clones the engine at a pinned ref and launches the install wizard

Fallback: see `INSTALL_ANDREW_V1.md` (fully inlined) and `TROUBLESHOOT_GIT.md`.

This repo is intentionally thin: it bootstraps `dawsos-engine` at a pinned tag/commit and launches the TUI wizard.
