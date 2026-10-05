# Install Nopeus Business

Run on your customer-owned Linux x86-64 server with Docker Engine 28 or newer:

```sh
curl -fsSL https://nopeus.xyz/install | bash
```

An existing Coolify Docker server works. The script requests sudo if needed, checks Docker, and runs the reviewed digest-pinned Business installer. It does not install or reconfigure Docker on your host.

1. Enter your dashboard hostname and confirm the VPS ingress IP (a detected outbound address is offered as a default).
2. Create the displayed DNS Type/Name/Value at the detected provider or your DNS provider, then type `done`. The installer verifies direct DNS resolution. Use Cloudflare DNS-only initially.
3. Choose Public (sign in from any device) or Private (VPN/network allowlist). No browser or laptop IP approval is required.
4. Choose web dashboard or terminal onboarding. Create company details, an administrator, and your own agents. Provider keys use hidden input in the CLI.
5. To add VPSs, create a server join code in Workspace settings → Servers or CLI setup. Run the displayed `--join` command on each new VPS and paste its one-time code. Agents are placed on the server you select and managed from one dashboard.

To supply the hostname explicitly:

```sh
curl -fsSL https://nopeus.xyz/install | bash -s -- --domain agents.customer.com
```

Keep the printed enrollment link private. Installation does not modify DNS and does not automatically connect to Nopeus telemetry. Customer data stays within the customer dashboard/worker deployment except messages sent to the model provider the customer chooses. Company details are saved locally. Telemetry activation is optional and separate from installation. Worker servers connect only to your customer dashboard over verified outbound HTTPS, and publish no control/runtime ports.

## Existing installations

Stop an earlier failed Coolify Business application before using the same hostname, and preserve its volumes. The new installer does not migrate the old fixed-agent Compose deployment.

Re-running the installer uses the same `nopeus-business-deployment` named volume and preserves existing workspace accounts and agent state. This script is pinned to a tested release. Updates are published after release checks pass. Back up the deployment configuration, dashboard state, and all agent state volumes together before upgrading. Do not delete volumes to troubleshoot.

## Server commands

Installation adds `/usr/local/bin/nopeus` to the VPS. Run:

```sh
nopeus upgrade
nopeus access public
nopeus setup
nopeus uninstall
```

Upgrade each VPS to the same tested release. Existing private installations stay private until you run `nopeus access public`. `nopeus setup` offers company/account/agent/server onboarding in the terminal. Upgrade downloads the latest tested installer and preserves the saved domain, allowed networks, proxy settings, users and agent data. It does not ask you to set up DNS or access again. Back up before upgrading. The commands request sudo if needed.

For an existing installation created before these commands were added, run this once to upgrade with saved settings and install the command:

```sh
curl -fsSL https://nopeus.xyz/install | bash -s -- --upgrade
```

## Uninstall

Run on the deployment server:

```sh
nopeus uninstall
```

Run uninstall on each worker VPS and then the dashboard; cleanup is local to that VPS and never erases another server remotely. Review the listed resources and type `DELETE` to permanently delete the installation and all its customer data. Back up first. This preserves Docker, Coolify, other applications and DNS records. Add `--remove-images` to attempt removal of the pinned image cache; images still in use are retained. This targets installations created by the one-command installer, not legacy Compose deployments.

## Inspect first

You can download `install.sh`, read it, then run `bash install.sh`. `SHA256SUMS` records the published script checksum. The distribution repository contains only this wrapper and instructions; the reviewed runtime images are publicly available on GHCR.
