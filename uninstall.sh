#!/usr/bin/env bash
set -euo pipefail
BUSINESS_IMAGE='ghcr.io/nopeus-ai/nopeus-business-control@sha256:3296054fe6741440dd46291c305e0b3d79900f3a8bfbefc3bf05458b458f23aa'
volume='nopeus-business-deployment'
remove_images=false
fail() { printf '\nNopeus Business: %s\n' "$*" >&2; exit 1; }
while (( $# )); do
  case "$1" in
    --help) cat <<'HELP'
Uninstall Nopeus Business from this Docker server.
Usage: curl -fsSL https://nopeus.xyz/uninstall | bash
Options: --volume NAME    Select a deployment configuration volume.
         --remove-images Also attempt to remove the pinned image cache (no force).
Permanently deletes this installation's accounts, agents, credentials and state.
Requires typing DELETE in your terminal. Back up your data first.
Coolify, Docker, other installations and external DNS records are preserved.
HELP
      exit 0 ;;
    --volume) [[ $# -ge 2 ]] || fail 'Missing volume name'; volume=$2; shift 2 ;;
    --remove-images) remove_images=true; shift ;;
    *) fail "Unknown option: $1" ;;
  esac
done
[[ "$volume" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || fail 'Invalid volume name'
command -v docker >/dev/null || fail 'Docker is required on the deployment server.'
if ! { exec 3<>/dev/tty; } 2>/dev/null; then fail 'Run in an interactive SSH terminal.'; fi
runner=(docker)
if [[ "$EUID" -ne 0 ]]; then
  sudo -v <&3 || fail 'Administrator access is required.'
  runner=(sudo docker)
fi
"${runner[@]}" info >/dev/null || fail 'Cannot reach Docker.'
if ! "${runner[@]}" volume inspect "$volume" >/dev/null 2>&1; then
  printf 'Deployment volume %s is absent. Nothing changed.\n' "$volume"
  exit 0
fi
# Read only the identity and image digests; never print installation secrets.
metadata=$("${runner[@]}" run --rm -i --network none --read-only --cap-drop ALL \
  --security-opt no-new-privileges:true --user 0 \
  -v "$volume:/deployment:ro" "$BUSINESS_IMAGE" python3 - "$volume" <<'PY'
import json,re,sys
from pathlib import Path
c=json.loads(Path('/deployment/installation.json').read_text())
assert re.fullmatch(r'[a-f0-9]{24}',c['instance']), 'Invalid installation identity'
assert c['deployment_volume']==sys.argv[1], 'Deployment volume identity mismatch'
print(c['instance'])
for k in ('control_image','hermes_image','caddy_image'):
    value=c[k]
    assert re.fullmatch(r'[a-z0-9./_-]+@sha256:[a-f0-9]{64}',value), 'Invalid image digest'
    print(value)
PY
) || fail 'Cannot verify installation identity. Nothing removed.'
mapfile -t fields <<< "$metadata"
instance=${fields[0]}
[[ "$instance" =~ ^[a-f0-9]{24}$ && ${#fields[@]} -eq 4 ]] || fail 'Invalid installation metadata'
owner='xyz.nopeus.business.instance'
filter="label=$owner=$instance"
collect() {
  local output
  output=$("${runner[@]}" ps -a --filter "$filter" --format '{{.Names}}') || fail 'Cannot list containers'
  mapfile -t containers <<< "$output"
  output=$("${runner[@]}" network ls --filter "$filter" --format '{{.Name}}') || fail 'Cannot list networks'
  mapfile -t networks <<< "$output"
  output=$("${runner[@]}" volume ls --filter "$filter" --format '{{.Name}}') || fail 'Cannot list volumes'
  mapfile -t volumes <<< "$output"
}
collect
printf '\nPermanently remove Nopeus Business installation %s:\n' "$instance"
for resource in "${containers[@]}" "${networks[@]}" "${volumes[@]}" "$volume"; do
  [[ -n "$resource" ]] && printf '  %s\n' "$resource"
done
printf '\nThis deletes all workspace accounts, agents, credentials, memory and audit data.\n'
printf 'Back up first. Type DELETE to confirm: '
read -r answer <&3
[[ "$answer" == DELETE ]] || { printf 'Cancelled. Nothing removed.\n'; exit 0; }
verify() {
  local kind=$1 resource=$2 actual
  [[ "$resource" == "nopeus-$instance-"* ]] || fail "Refusing unexpected resource: $resource"
  if [[ "$kind" == container ]]; then
    actual=$("${runner[@]}" inspect --format "{{index .Config.Labels \"$owner\"}}" "$resource")
  else
    actual=$("${runner[@]}" "$kind" inspect --format "{{index .Labels \"$owner\"}}" "$resource")
  fi
  [[ "$actual" == "$instance" ]] || fail "Ownership changed: $resource"
}
# Stop the provisioner before rescanning so it cannot create more agent resources.
for resource in "${containers[@]}"; do
  [[ "$resource" == "nopeus-$instance-provisioner" ]] || continue
  verify container "$resource"
  "${runner[@]}" stop --time 30 "$resource" >/dev/null
done
collect
for resource in "${containers[@]}"; do
  [[ -n "$resource" ]] || continue
  verify container "$resource"
  "${runner[@]}" rm -f "$resource" >/dev/null
done
for resource in "${networks[@]}"; do
  [[ -n "$resource" ]] || continue
  verify network "$resource"
  "${runner[@]}" network rm "$resource" >/dev/null
done
for resource in "${volumes[@]}"; do
  [[ -n "$resource" ]] || continue
  verify volume "$resource"
  "${runner[@]}" volume rm "$resource" >/dev/null
done
# Last: retain the identity/configuration if any earlier removal fails.
"${runner[@]}" volume rm "$volume" >/dev/null
if "$remove_images"; then
  for resource in "${fields[@]:1}"; do
    if ! "${runner[@]}" image rm "$resource"; then
      printf 'Image retained because Docker could not remove it: %s\n' "$resource"
    fi
  done
fi
printf '\nNopeus Business and its customer data have been removed.\n'
printf 'Remove the dashboard DNS record separately if it is no longer needed.\n'
