# Troubleshooting: Git access (private repos)

If the installer gets stuck at `git clone` or prompts for a password, it means GitHub auth is not correctly configured.

## 1) Ensure you are not root
```bash
whoami
```

## 2) Log in with GitHub CLI (browser/device flow)
```bash
gh auth login -h github.com -p https -w
gh auth setup-git
```

## 3) Prove repo access (must show viewerPermission=READ or higher)
```bash
gh repo view mwd474747/dawsos-engine --json name,viewerPermission
```

## 4) If access fails
- Accept the repo invitation email or GitHub notification.
- Ensure you logged into the same GitHub account that was invited.

## 5) Reset auth if needed
```bash
gh auth logout -h github.com
gh auth login -h github.com -p https -w
gh auth setup-git
```

## 6) Avoid PATs
We do not use personal access tokens for partner installs.
