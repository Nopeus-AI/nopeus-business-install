#!/usr/bin/env bash
# Public distribution wrapper. Product source and customer configuration stay private.
set -euo pipefail

BUSINESS_IMAGE='ghcr.io/nopeus-ai/nopeus-business-control@sha256:ff073f5a2a47bf3cc3403894475b3a26beb003dfde2279a953debcb98c600cce'
BUSINESS_VOLUME='nopeus-business-deployment'

fail() { printf '\nNopeus Business: %s\n' "$*" >&2; exit 1; }

if [[ "${1:-}" == '--help' ]]; then
  cat <<'HELP'
Install Nopeus Business on a Linux x86-64 Docker host.
Usage: curl -fsSL INSTALLER_URL | bash
       curl -fsSL INSTALLER_URL | bash -s -- --domain agents.example.com

Requires Docker Engine 28+ (already present on supported Coolify servers).
Prompts use your terminal. Existing workspace data is preserved on reinstall.
After installation: nopeus upgrade | nopeus access public | nopeus setup | nopeus uninstall
Use --upgrade to upgrade an existing installation with saved settings.
Additional installation arguments are passed to the reviewed Business installer.
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


install_command() {
  local destination='/usr/local/bin/nopeus' command_tmp
  local admin=()
  [[ "$EUID" -eq 0 ]] || admin=(sudo)
  if [[ -L "$destination" ]] || { [[ -e "$destination" ]] && ! owned_command "$destination"; }; then
    fail 'Refusing to replace an existing unrelated /usr/local/bin/nopeus command.'
  fi
  command_tmp=$("${admin[@]}" mktemp "${destination%/*}/.nopeus.XXXXXX")
  if ! {
    "${admin[@]}" tee "$command_tmp" >/dev/null <<'NOPEUS_COMMAND'
#!/usr/bin/env bash
# Nopeus Business customer command.
set -euo pipefail
case "${1:---help}" in
  upgrade) endpoint=install; shift; args=(--upgrade "$@") ;;
  access) endpoint=install; shift; [[ "${1:-}" == public || "${1:-}" == private ]] || { printf 'Use: nopeus access public | private\n' >&2; exit 1; }; mode=$1; shift; args=(--upgrade --access "$mode" "$@") ;;
  setup) endpoint=install; shift; args=(--upgrade --setup cli "$@") ;;
  join) endpoint=install; shift; [[ -n "${1:-}" ]] || { printf 'Use: nopeus join https://your-dashboard-domain\n' >&2; exit 1; }; args=(--join "$@") ;;
  uninstall) endpoint=uninstall; shift; args=("$@") ;;
  --help|help|-h) cat <<'HELP'
Nopeus Business — run on your deployment server.

  nopeus upgrade     Upgrade to the latest tested release, keeping your settings and data.
  nopeus access public|private   Set dashboard network access (login is always required).
  nopeus setup       Configure your company, administrator and agents in this terminal.
  nopeus join URL    Connect this VPS as a worker to your dashboard; enter its join code when prompted.
  nopeus uninstall   Remove this installation and its data after confirmation.

Back up your deployment before upgrading or uninstalling.
HELP
    exit 0 ;;
  *) printf 'Unknown command. Use: nopeus help\n' >&2; exit 1 ;;
esac
command -v curl >/dev/null || { printf 'curl is required.\n' >&2; exit 1; }
download=$(mktemp)
trap 'rm -f -- "$download"' EXIT
# Download completely before executing; a failed transfer never runs a partial script.
curl -fsSL --connect-timeout 10 --max-time 120 "https://nopeus.xyz/$endpoint" -o "$download"
bash "$download" "${args[@]}"
NOPEUS_COMMAND
    "${admin[@]}" chown 0:0 "$command_tmp" && "${admin[@]}" chmod 755 "$command_tmp" && "${admin[@]}" mv -fT "$command_tmp" "$destination"
  }; then
    "${admin[@]}" rm -f -- "$command_tmp"
    fail 'Business is running, but the local nopeus command could not be installed.'
  fi
  printf '\nServer commands are ready: nopeus upgrade | nopeus uninstall\n'
}
owned_command() {
  local line
  { read -r line; read -r line; } < "$1"
  [[ "$line" == '# Nopeus Business customer command.' ]]
}

# Refuse a name collision before changing an existing deployment.
if [[ -L /usr/local/bin/nopeus ]] || { [[ -e /usr/local/bin/nopeus ]] && ! owned_command /usr/local/bin/nopeus; }; then
  fail 'Refusing to replace an existing unrelated /usr/local/bin/nopeus command.'
fi

if [[ "${1:-}" == '--upgrade' ]]; then
  shift
  overrides=("$@")
  while (( $# )); do
    case "$1" in
      --access|--setup|--allowed-ips) [[ $# -ge 2 ]] || fail "Missing value for $1"; shift 2 ;;
      *) fail "Unsupported upgrade option: $1" ;;
    esac
  done
  "${runner[@]}" volume inspect "$BUSINESS_VOLUME" >/dev/null 2>&1 || fail 'No installation found. Run the initial installer first.'
  printf '\nUpgrading Nopeus Business to the latest tested release. Existing settings and data are preserved.\n'
  saved=$("${runner[@]}" run --rm -i --network none --read-only --cap-drop ALL --security-opt no-new-privileges:true \
    --user 10001:10001 -v "$BUSINESS_VOLUME:/deployment:ro" "$BUSINESS_IMAGE" python3 - "$BUSINESS_VOLUME" <<'PY_CONFIG'
import json,re,sys
from pathlib import Path
c=json.loads(Path('/deployment/installation.json').read_text())
assert re.fullmatch(r'[a-f0-9]{24}',c['instance']), 'Invalid installation identity'
assert c['deployment_volume']==sys.argv[1], 'Deployment volume identity mismatch'
assert c['mode'] in ('coolify','standalone','local','worker'), 'Invalid deployment mode'
assert type(c['port']) is int and 1024 <= c['port'] <= 65535, 'Invalid dashboard port'
args=['--mode',c['mode'],'--port',str(c['port'])]
for key,flag in [('proxy_network','--proxy-network'),('tls_resolver','--tls-resolver')]:
    value=c[key]
    assert isinstance(value,str) and re.fullmatch(r'[a-zA-Z0-9_.-]{1,80}',value), 'Invalid proxy setting'
    args.extend([flag,value])
if c['mode']=='worker':
    value=c['dashboard_url']
    assert isinstance(value,str) and value.startswith('https://') and not any(x in value for x in '\r\n\0'), 'Invalid dashboard URL'
    args.extend(['--join', value])
elif c['mode']!='local':
    assert c.get('access','private') in ('public','private'), 'Invalid access mode'
    args.extend(['--access', c.get('access','private')])
    for key,flag in [('domain','--domain'),('allowed_ips','--allowed-ips')]:
        value=c[key]
        assert isinstance(value,str) and not any(x in value for x in '\r\n\0'), 'Invalid dashboard setting'
        if value: args.extend([flag,value])
args.append('--upgrade')
print('\n'.join(args))
PY_CONFIG
  ) || fail 'Cannot read the existing installation settings. Nothing changed.'
  mapfile -t saved_args <<< "$saved"
  "${runner[@]}" run --rm -it --user 0 -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$BUSINESS_VOLUME:/deployment" "$BUSINESS_IMAGE" python3 -m business.install "${saved_args[@]}" "${overrides[@]}" <&3
  install_command
  exit 0
fi

printf '\nInstalling Nopeus Business on this server.\n'
install_command
"${runner[@]}" run --rm -it --user 0 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$BUSINESS_VOLUME:/deployment" \
  "$BUSINESS_IMAGE" python3 -m business.install "$@" <&3
