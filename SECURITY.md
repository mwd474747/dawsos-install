# Security Policy (Installer Repo)

This repository (`dawsos-install`) is **public by design**.

## Non-negotiables
- **No secrets** in this repo (no tokens, passwords, private keys, MCP auth tokens, etc.).
- Installer must not prompt users to paste secrets into Terminal.
- Anything partner-facing must use stable, versioned references (tags/releases), not moving branches.

## Supply chain
- Engine bundle downloads are verified via SHA256.
- Future hardening: GitHub Artifact Attestations (SLSA) and signing (cosign).
