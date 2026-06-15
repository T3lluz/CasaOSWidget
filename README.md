# CasaOS Homelab

A KDE Plasma 6 panel widget that monitors your [CasaOS](https://github.com/IceWhaleTech/CasaOS) homelab server — CPU, RAM, disk, temperature, network, and service health — and lets you reboot it without leaving the desktop.

![Plasma 6](https://img.shields.io/badge/Plasma-6-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

**Panel (always visible, single line)**

- Live connection status dot (pulses while connecting)
- Server name, CPU %, RAM %, disk used/total, CPU temperature, network ↓/↑
- Scales to whatever width you give the widget on the panel
- Click to open the popup, middle-click to refresh immediately

**Popup (click to expand)**

- Header card with server avatar, status text, CasaOS version and last-update timestamp
- Three big gauge rings for CPU, RAM and disk
- CPU and RAM history sparklines, plus dedicated download/upload sparklines
- Per-interface network breakdown
- CasaOS services panel (running/stopped chips)
- Installed apps grid with store icons and running-state dots
- System info card — CPU (vendor · cores · temperature), architecture, memory, storage and CasaOS version. Extra fields (kernel, OS, hostname, uptime, BIOS, …) are shown automatically when your CasaOS build exposes them — the stock CasaOS API only reports architecture and CPU vendor
- Three header buttons: **refresh**, **open dashboard**, **reboot server** (with confirmation)

The widget is dark, minimal, and data-rich by design — the same Power-Deck-style aesthetic regardless of your active Plasma color scheme.

## Requirements

- KDE Plasma **6.0+**
- Qt **6**
- A CasaOS server reachable over your network (LAN or Tailscale)
- CasaOS user credentials (the same ones you use for the web UI)

## Installation

### One-line install (recommended)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/T3lluz/CasaOSWidget/main/install.sh)
```

The script will shallow-clone the repo into a temp directory and register the
widget through `kpackagetool6`. Re-run the same command at any time to upgrade.

### From a local checkout

```bash
git clone https://github.com/T3lluz/CasaOSWidget.git
cd CasaOSWidget
./install.sh
```

### After installing

Reload Plasma so the widget shows up:

```bash
kquitapp6 plasmashell && kstart plasmashell
```

Add the widget: right-click the panel → **Add Widgets** → search **CasaOS Homelab**. Stretch it on the panel to whatever width you want — the layout adapts.

### Uninstall

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/T3lluz/CasaOSWidget/main/install.sh) --uninstall
```

Or, from a local checkout:

```bash
./install.sh --uninstall
```

## Configuration

Right-click the widget → **Configure CasaOS Homelab**:

| Setting | Description |
|---------|-------------|
| **Server URL** | Gateway URL, e.g. `http://100.x.x.x` or `http://192.168.1.10`. Protocol optional. |
| **Display name** | Label shown in the panel and popup header. |
| **Username / Password** | Your CasaOS login. |
| **Refresh interval** | How often to poll the API (2–120 s). |

## How it works

The widget authenticates against the CasaOS user API (`POST /v1/users/login`) and caches the access token. It then polls these endpoints on each refresh:

| Endpoint | Purpose |
|----------|---------|
| `GET /v1/sys/utilization` | CPU, RAM, disk, per-interface network |
| `GET /v1/sys/hardware/info` (falls back to `/v1/sys/hardware`) | Device model + CPU architecture |
| `GET /v2/app_management/compose` (falls back to `/v1/apps`) | Installed apps, status and store icons |
| `GET /v2/casaos/health/services` | Running and stopped `casaos-*` services |
| `GET /v1/sys/version/current` | CasaOS version string |
| `PUT /v1/sys/restart` | Reboot the server (header button) |

Each request has a 6 s timeout so a dead server is detected quickly. On a `401`, the cached token is dropped and the widget re-logs in transparently. The connection status dot reflects the last known state (`connected`, `connecting`, or `error` with a human-readable message).

## Development

Test in a standalone window:

```bash
plasmawindowed org.fredde.casaos.homelab
```

Project layout:

```
metadata.json
install.sh
contents/
  config/          # KCM settings schema (main.xml + config.qml)
  ui/              # QML sources
    main.qml                  # PlasmoidItem entry point
    Theme.qml                 # Centralized colors + metrics
    CasaOSClient.qml          # API client (login, polling, restart)
    CompactRepresentation.qml # Single-line panel view
    FullRepresentation.qml    # Rich popup
    GaugeRing.qml             # Animated dial gauge
    SparklineChart.qml        # Bezier sparkline with gradient fill
    MetricIcon.qml            # Canvas-drawn metric / action icons
    configGeneral.qml         # KCM page
```

## License

MIT — see [LICENSE](LICENSE).
