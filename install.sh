#!/usr/bin/env bash
set -euo pipefail

# DawsOS public bootstrapper.
#
# - Safe to host publicly: contains NO secrets.
# - Uses GitHub device/browser flow (gh) to access private engine repo.
# - Downloads and runs the current Andrew v1 bootstrap script.

BOOTSTRAP_URL="https://raw.githubusercontent.com/mwd474747/dawsos-install/main/bootstrap_andrew_v1.sh"

curl -fsSL "$BOOTSTRAP_URL" -o /tmp/bootstrap_andrew_v1.sh
chmod +x /tmp/bootstrap_andrew_v1.sh
exec /tmp/bootstrap_andrew_v1.sh
