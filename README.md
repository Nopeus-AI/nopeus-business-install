# Install Nopeus Business

Run on your customer-owned Linux x86-64 server with Docker Engine 28 or newer:

```sh
curl -fsSL https://raw.githubusercontent.com/Nopeus-AI/nopeus-business-install/main/install.sh | bash
```

An existing Coolify Docker server works. The script requests sudo if needed, checks Docker, and runs the reviewed digest-pinned Business installer. It does not install or reconfigure Docker on your host.

1. Point your dashboard hostname's DNS at this server. For private network access, use DNS that resolves correctly from the client/VPN network. HTTPS needs a working certificate resolver; default public certificate issuance needs reachable validation.
2. Enter that hostname when prompted, without `https://` or a path.
3. Enter your client/VPN IP ranges. Press Enter for private ranges. A public VPN exit address must be explicitly allowed (a single IPv4 address uses `/32`).
4. Open the printed private setup link from your allowed network and create your workspace and administrator account.
5. Choose and create your agents in the dashboard, including their purposes and provider/model credentials. No agents or provider keys are required to install the workspace.

To supply the hostname explicitly:

```sh
curl -fsSL https://raw.githubusercontent.com/Nopeus-AI/nopeus-business-install/main/install.sh | bash -s -- --domain agents.customer.com
```

Keep the printed enrollment link private. Installation does not modify DNS and does not automatically connect to Nopeus telemetry. Customer data stays on this server except messages sent to the model provider the customer chooses. Full organisation-profile and telemetry-activation onboarding are not part of release 0.2.0.

## Existing installations

Stop an earlier failed Coolify Business application before using the same hostname, and preserve its volumes. The new installer does not migrate the old fixed-agent Compose deployment.

Re-running the installer uses the same `nopeus-business-deployment` named volume and preserves existing workspace accounts and agent state. This script is pinned to a tested release. Updates are published after release checks pass. Back up the deployment configuration, dashboard state, and all agent state volumes together before upgrading. Do not delete volumes to troubleshoot.

## Inspect first

You can download `install.sh`, read it, then run `bash install.sh`. `SHA256SUMS` records the published script checksum. The distribution repository contains only this wrapper and instructions; the reviewed runtime images are publicly available on GHCR.
