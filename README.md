# CasaOS Homelab

A KDE Plasma 6 panel widget that monitors your [CasaOS](https://github.com/IceWhaleTech/CasaOS) homelab server — CPU, RAM, disk, temperature, network, and service health — directly from the desktop panel.

![Plasma 6](https://img.shields.io/badge/Plasma-6-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

**Panel (always visible)**

- Live connection status indicator
- Server name and CPU temperature
- CPU and RAM usage percentages with mini progress bars
- Disk usage as `used/total` (e.g. `412G/1T`)

**Popup (click to expand)**

- Gauge rings for CPU, RAM, and disk
- CPU and RAM history sparkline charts
- Network download/upload rates and per-interface stats
- CasaOS service health (`casaos-*` services)
- Hardware info and one-click open of the CasaOS dashboard

## Requirements

- KDE Plasma **6.0+**
- Qt **6**
- A CasaOS server reachable over your network (LAN or Tailscale)
- CasaOS user credentials (same as the web UI login)

## Installation

```bash
git clone https://github.com/T3lluz/CasaOSWidget.git
cd CasaOSWidget
./install.sh
```

Then reload Plasma:

```bash
kquitapp6 plasmashell && kstart plasmashell
```

Add the widget: right-click the panel → **Add Widgets** → search **CasaOS Homelab**.

To upgrade an existing install, run `./install.sh` again.

## Configuration

Right-click the widget → **Configure CasaOS Homelab**:

| Setting | Description |
|---------|-------------|
| **Server URL** | CasaOS gateway URL, e.g. `http://100.x.x.x` or `http://192.168.1.10` |
| **Display name** | Label shown in the panel |
| **Username / Password** | Your CasaOS login |
| **Refresh interval** | How often to poll the API (seconds) |
| **Panel display** | Full (with bars), compact (numbers only), or minimal (no server name) |

## How it works

The widget authenticates against the CasaOS user API (`POST /v1/users/login`), then polls:

- `GET /v1/sys/utilization` — CPU, RAM, network, disk
- `GET /v1/sys/hardware` — device model and architecture
- `GET /v2/casaos/health/services` — running CasaOS services
- `GET /v1/sys/version/current` — CasaOS version

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
  config/          # KCM settings schema
  ui/              # QML sources
```

## License

MIT — see [LICENSE](LICENSE).
