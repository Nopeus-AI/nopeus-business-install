#!/usr/bin/env bash
# Public distribution wrapper. Product source and customer configuration stay private.
set -euo pipefail

BUSINESS_IMAGE='ghcr.io/nopeus-ai/nopeus-business-control@sha256:3296054fe6741440dd46291c305e0b3d79900f3a8bfbefc3bf05458b458f23aa'
BUSINESS_VOLUME='nopeus-business-deployment'

fail() { printf '\nNopeus Business: %s\n' "$*" >&2; exit 1; }

if [[ "${1:-}" == '--help' ]]; then
  cat <<'HELP'
Install Nopeus Business on a Linux x86-64 Docker host.
Usage: curl -fsSL INSTALLER_URL | bash
       curl -fsSL INSTALLER_URL | bash -s -- --domain agents.example.com

Requires Docker Engine 28+ (already present on supported Coolify servers).
Prompts use your terminal. Existing workspace data is preserved on reinstall.
Additional arguments are passed to the reviewed Business installer.
HELP
  exit 0
fi

[[ "$(uname -s)" == Linux ]] || fail 'Run this on your Linux deployment server.'
[[ "$(uname -m)" == x86_64 ]] || fail 'This release requires an x86-64 server.'
command -v docker >/dev/null 2>&1 || fail 'Docker Engine 28+ is required. Install Docker first, or use your existing Coolify server.'
# bash reads this script from the curl pipe; Docker must read the controlling terminal.
if ! { exec 3<>/dev/tty; } 2>/dev/null; then
  fail 'An interactive terminal is required. Connect with SSH and run the installer there.'
fi
runner=(docker)
if [[ "$EUID" -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 || fail 'Run as root, or install sudo to authorize Docker setup.'
  sudo -v <&3 || fail 'Administrator access is required for installation.'
  runner=(sudo docker)
fi
version=$("${runner[@]}" version --format '{{.Server.Version}}' 2>/dev/null) || fail 'Cannot reach Docker. Start the Docker service and retry.'
major=${version%%.*}
[[ "$major" =~ ^[0-9]+$ ]] && (( major >= 28 )) || fail 'Docker Engine 28 or newer is required.'

printf '\nInstalling Nopeus Business 0.2.0 on this server.\n'
printf 'You will enter a dashboard hostname and your client/VPN IP ranges.\n'
printf 'Accounts, agents, and provider keys are configured in the web dashboard.\n\n'
"${runner[@]}" run --rm -it --user 0 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$BUSINESS_VOLUME:/deployment" \
  "$BUSINESS_IMAGE" python3 -m business.install "$@" <&3
