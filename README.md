# Install Nopeus Business

Run on your customer-owned Linux x86-64 server with Docker Engine 28 or newer:

```sh
curl -fsSL https://nopeus.xyz/install | bash
```

An existing Coolify Docker server works. The script requests sudo if needed, checks Docker, and runs the reviewed digest-pinned Business installer. It does not install or reconfigure Docker on your host.

1. Enter your owner email, then your dashboard hostname and confirm the VPS ingress IP (a detected outbound address is offered as a default). The installer explains the install check-in before asking for your email.
2. Create the displayed DNS Type/Name/Value at the detected provider or your DNS provider, then type `done`. The installer verifies direct DNS resolution. Use Cloudflare DNS-only initially.
3. Choose Public (sign in from any device) or Private (VPN/network allowlist). No browser or laptop IP approval is required.
4. Choose web dashboard or terminal onboarding. Create company details, an administrator, and your own agents. Provider keys use hidden input in the CLI.
5. To add VPSs, create a server join code in Workspace settings → Servers or CLI setup. Run the displayed `--join` command on each new VPS and paste its one-time code. Agents are placed on the server you select and managed from one dashboard.

To supply the hostname explicitly:

```sh
curl -fsSL https://nopeus.xyz/install | bash -s -- --domain agents.customer.com
```

License enforcement is temporarily paused. Workspace setup and agent operation do not require license activation or a license server. Automatic license polling and license usage reporting are paused too.

Keep the printed enrollment link private. Installation does not modify DNS and does not automatically connect to Nopeus telemetry. Customer data stays within the customer dashboard/worker deployment except messages sent to the model provider the customer chooses. Company details are saved locally. Install-registry check-in sends your owner email, machine name, a random install ID, version, and usage counts at installation and daily; it excludes business data, messages, files, and credentials. Operational support telemetry is optional and separate from that check-in. Worker servers connect only to your customer dashboard over verified outbound HTTPS, and publish no control/runtime ports.

## Conversations and messaging

Web conversations are saved on the owning agent server and restore when you sign in again. Open an agent → Channels in its chat header to configure the runtime’s native platforms, including Telegram and both WhatsApp methods. Customers supply their own platform credentials or complete native QR pairing. Some platforms require external bridges or webhook ingress. Pausing an agent also pauses its channel gateway. Credentials, transcripts and business content are excluded from Nopeus telemetry.

## Agent collaboration

Business 0.7.5 makes collaboration automatic in dashboard chats. Agents decide when to use temporary helpers or delegate work to another active agent the person starting the chat can operate. No collaboration setup is required. Each turn can use up to four child tasks; children return findings to the parent and cannot delegate further. The chat shows progress and results and offers Cancel run. Extra calls use your connected provider accounts; model calls already dispatched may finish after cancellation. Upgrade the dashboard and every worker to the same version.

## Agent screen

Business 0.7.5 has one workspace sidebar with Output and Screen tabs. Open it from the chat header. Output shows the latest successful response in the selected conversation and supports copying; it is a view of the reply, not a separate document. Screen shows the agent's desktop with fullscreen viewing and browser navigation, click, and typing controls. Switching to Output or closing the sidebar stops frame loading. On phones the sidebar fills the chat area. An idle agent shows a waiting state until its desktop is running. Upgrade the dashboard and each worker VPS to the same release. The agent screen follows the selected agent's access grant. Dashboard approvals record decisions; native tools can perform writes and do not use those records as an authorization gate.

## Shared Apps and Credentials

Business 0.7.5 adds Settings → Apps and Credentials. Save generic API or remote HTTPS MCP connections once, then choose which agents can use them in Setup & connections. Applied connections stay in the agent runtime across web and messaging channels. Dedicated integrations such as HubSpot and Shopify will be added over time.

Credentials support individual access, an explicit all-credentials grant, secret replacement, and Chrome/Apple Passwords CSV import. Back up the dashboard database together with its adjacent connections.key and agent volumes. This release uses database schema 10; rollback requires a matching pre-upgrade backup. Native Hermes plugin and skill setup remains available through the CLI.

## Continue setup and change connections

Unfinished agent setup saves one draft to your workspace account. Close it or choose Save for later, then use Continue setup in the sidebar to resume, including from another device. Unsaved API keys are excluded from drafts; enter them again when you return. An agent awaiting account sign-in shows its own Continue setup action.

Click the model button in an agent's chat header to change its provider or model. Connected backups can become the primary without re-entering their stored keys. Channels opens platform setup directly and protects unsaved edits. An unexpired pairing can continue after reopening in the same browser tab. Settings → General offers Dark, Light and System.

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

Upgrade each VPS to the same tested release. Existing private installations stay private until you run `nopeus access public`. `nopeus setup` offers company/account/agent/server onboarding in the terminal. Upgrade downloads the latest tested installer and preserves the saved domain, allowed networks, proxy settings, users and agent data. If the saved release image already matches the latest tested release, it reports "Already on the latest version" and skips image downloads and deployment changes. It does not ask you to set up DNS or access again. Back up before upgrading. The commands request sudo if needed.

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
