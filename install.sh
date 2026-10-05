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
printf 'Accounts, agents, and provider keys are configured in the web dashboard.\n\n'

# An explicit setting (including one generated in the customer's browser) wins.
access_args=()
explicit_access=false
for arg in "$@"; do
  case "$arg" in --allowed-ips|--allowed-ips=*) explicit_access=true ;; esac
done
if ! "$explicit_access"; then
  connection=${SSH_CONNECTION:-${SSH_CLIENT:-}}
  client=${connection%% *}
  detected=''
  if [[ "$client" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    valid=true
    IFS=. read -r -a octets <<< "$client"
    for part in "${octets[@]}"; do (( 10#$part <= 255 )) || valid=false; done
    if "$valid" && (( 10#${octets[0]} > 0 && 10#${octets[0]} < 224 && 10#${octets[0]} != 127 )); then detected="$client/32"; fi
  elif [[ "$client" == *:* && "$client" =~ ^[a-fA-F0-9:]+$ && "$client" != '::1' && "$client" != '::' ]]; then
    detected="$client/128"
  fi
  if [[ -n "$detected" ]]; then
    printf 'Detected your SSH connection: %s\n' "$client"
    printf 'Dashboard access:\n  1) Allow this connection (default)\n  2) Use a private VPN or network\n  3) Advanced: enter allowed addresses\n'
    printf 'Choose [1]: '
    read -r choice <&3
    case "${choice:-1}" in
      1) access_args=(--allowed-ips "$detected") ;;
      2) access_args=(--allowed-ips '10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10,fc00::/7') ;;
      3) ;;
      *) fail 'Choose 1, 2, or 3 and run the installer again.' ;;
    esac
  else
    printf 'No direct SSH connection was detected.\n'
    printf 'For browser access from this device, open https://nopeus.xyz/install-access/\n'
    printf 'It detects your connection and supplies a command automatically.\n'
    printf 'Use a private VPN/network instead? [Y/n]: '
    read -r choice <&3
    case "${choice:-y}" in
      y|Y|yes|YES) access_args=(--allowed-ips '10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10,fc00::/7') ;;
      n|N|no|NO) printf 'Open the page above on your device and run its generated command here.\n'; exit 0 ;;
      *) fail 'Answer yes or no and run the installer again.' ;;
    esac
  fi
fi
if (( ${#access_args[@]} )); then
  printf 'This access choice will also apply if you reinstall an existing workspace.\n'
fi
# Prepare DNS before starting services or printing an enrollment link.
host=''
args=("$@")
for ((index=0; index<${#args[@]}; index++)); do
  case "${args[index]}" in
    --domain) host=${args[index+1]:-} ;;
    --domain=*) host=${args[index]#--domain=} ;;
  esac
done
if [[ -z "$host" ]]; then printf 'Dashboard hostname (e.g. agents.yourcompany.com): '; read -r host <&3; fi
host=${host,,}
[[ "$host" =~ ^[a-z0-9][a-z0-9.-]*[a-z0-9]$ && "$host" == *.* && ${#host} -le 253 ]] || fail 'Enter a hostname without https:// or a path.'
IFS=. read -r -a labels <<< "$host"
for label in "${labels[@]}"; do
  [[ "$label" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ && ${#label} -le 63 ]] || fail 'Invalid dashboard hostname.'
done
printf '\nSet up DNS before continuing:\n'
printf '  Name: %s\n  Type: A for an IPv4 server address, or AAAA for IPv6.\n' "$host"
printf '  Value: your server address from your hosting or VPN settings.\n'
server_hint=$(curl -4 -fsS --connect-timeout 3 --max-time 5 'https://nopeus.xyz/api/install-access?format=text' 2>/dev/null) || server_hint=''
if [[ "$server_hint" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  printf '  Detected server outbound IPv4: %s (use only if it is also the server ingress address).\n' "$server_hint"
fi
printf 'A CNAME is suitable only if your hosting provider gives you a target hostname.\n'
printf 'For private access, use the server VPN/private address and DNS visible on that network.\n'
printf 'If using Cloudflare DNS, use DNS-only; proxied access needs a separate trusted-proxy configuration.\n'
while true; do
  printf '\nCreate/check the DNS record, then press Enter to verify (q to stop): '
  read -r answer <&3
  [[ "$answer" != q && "$answer" != Q ]] || exit 0
  resolved=''
  if command -v getent >/dev/null 2>&1; then
    resolved=$(getent ahosts "$host" 2>/dev/null | awk '{print $1}' | sort -u) || resolved=''
  else
    resolved=$("${runner[@]}" run --rm --read-only --cap-drop ALL --security-opt no-new-privileges:true --network host "$BUSINESS_IMAGE" python3 -c 'import socket,sys; print("\n".join(sorted({x[4][0] for x in socket.getaddrinfo(sys.argv[1],443,type=socket.SOCK_STREAM)})))' "$host" 2>/dev/null) || resolved=''
  fi
  if [[ -z "$resolved" ]]; then printf 'The hostname does not resolve from this server yet. Wait for DNS propagation and retry.\n'; continue; fi
  printf 'DNS resolves to:\n%s\n' "$resolved"
  printf 'Are these the addresses of this server or its intended ingress? [Y/n]: '
  read -r answer <&3
  case "${answer:-y}" in y|Y|yes|YES) break ;; esac
  printf 'Correct the DNS record and retry. No services have been changed yet.\n'
done
printf 'DNS resolution checked. HTTPS issuance and access from your device still depend on your proxy/VPN.\n\n'
"${runner[@]}" run --rm -it --user 0 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$BUSINESS_VOLUME:/deployment" \
  "$BUSINESS_IMAGE" python3 -m business.install "$@" --domain "$host" "${access_args[@]}" <&3
