# Install Nopeus Business

Run on your customer-owned Linux x86-64 server with Docker Engine 28 or newer:

```sh
curl -fsSL https://nopeus.xyz/install | bash
```

An existing Coolify Docker server works. The script requests sudo if needed, checks Docker, and runs the reviewed digest-pinned Business installer. It does not install or reconfigure Docker on your host.

1. Point your dashboard hostname's DNS at this server. For private network access, use DNS that resolves correctly from the client/VPN network. HTTPS needs a working certificate resolver; default public certificate issuance needs reachable validation.
2. Enter that hostname when prompted, without `https://` or a path.
3. Confirm the detected SSH connection or choose private VPN/network access. From a browser terminal, visit https://nopeus.xyz/install-access/ on your device to get a command with access filled in automatically. The installer checks DNS resolution and asks you to confirm the server destination before starting services.
4. Open the printed private setup link from your allowed network and create your workspace and administrator account.
5. Choose and create your agents in the dashboard, including their purposes and provider/model credentials. No agents or provider keys are required to install the workspace.

To supply the hostname explicitly:

```sh
curl -fsSL https://nopeus.xyz/install | bash -s -- --domain agents.customer.com
```

Keep the printed enrollment link private. Installation does not modify DNS and does not automatically connect to Nopeus telemetry. Customer data stays on this server except messages sent to the model provider the customer chooses. Full organisation-profile and telemetry-activation onboarding are not part of release 0.2.2.

## Existing installations

Stop an earlier failed Coolify Business application before using the same hostname, and preserve its volumes. The new installer does not migrate the old fixed-agent Compose deployment.

Re-running the installer uses the same `nopeus-business-deployment` named volume and preserves existing workspace accounts and agent state. This script is pinned to a tested release. Updates are published after release checks pass. Back up the deployment configuration, dashboard state, and all agent state volumes together before upgrading. Do not delete volumes to troubleshoot.

## Server commands

Installation adds `/usr/local/bin/nopeus` to the VPS. Run:

```sh
nopeus upgrade
nopeus uninstall
```

Upgrade downloads the latest tested installer and preserves the saved domain, allowed networks, proxy settings, users and agent data. It does not ask you to set up DNS or access again. Back up before upgrading. The commands request sudo if needed.

For an existing installation created before these commands were added, run this once to upgrade with saved settings and install the command:

```sh
curl -fsSL https://nopeus.xyz/install | bash -s -- --upgrade
```

## Uninstall

Run on the deployment server:

```sh
nopeus uninstall
```

Review the listed resources and type `DELETE` to permanently delete the installation and all its customer data. Back up first. This preserves Docker, Coolify, other applications and DNS records. Add `--remove-images` to attempt removal of the pinned image cache; images still in use are retained. This targets installations created by the one-command installer, not legacy Compose deployments.

## Inspect first

You can download `install.sh`, read it, then run `bash install.sh`. `SHA256SUMS` records the published script checksum. The distribution repository contains only this wrapper and instructions; the reviewed runtime images are publicly available on GHCR.
