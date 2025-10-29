# dyckymost Configuration Backup

Raspberry Pi 4 Model B Rev 1.5 running Debian 12 (Bookworm)

## Contents

### Core Configuration
- `wireguard/prague0.conf` - WireGuard VPN to Czech Republic (key redacted)
- `nftables.conf` - Firewall, NAT, MSS clamping, kill switch
- `hosts` - Local hostname mappings

### Routing
- `iproute2/rt_protos` - Custom route protocol (prague-wg)
- `iproute2/rt_tables` - Routing table definitions

### NetworkManager
- `NetworkManager/system-connections/hotspot.nmconnection` - WiFi hotspot (password redacted)
- `NetworkManager/conf.d/dns.conf` - Use dnsmasq for system DNS
- `NetworkManager/dnsmasq-shared.d/split.conf` - DNS config for edge instances (wlan0, eth1)
- `NetworkManager/dnsmasq.d/split.conf` - DNS config for master resolver (127.0.0.1)
- `NetworkManager/dispatcher.d/99-local-routing` - Interface state change handler

### Custom Scripts
- `local/sbin/jump-main` - Add policy routing rules for interfaces
- `local/bin/pre-backup-script.sh` - Generate package lists before backup

### Backup System
- `rsnapshot.conf` - Backup configuration (30-day retention)
- `cron.d/rsnapshot` - Daily backup schedule at midnight

### System Configuration
- `sysctl.d/98-rpi.conf` - Raspberry Pi specific settings
- `sysctl.d/99-disable-ipv6.conf` - Disable IPv6 system-wide
- `sysctl.d/99-routing.conf` - IP forwarding and routing settings

### Boot Configuration
- `config.txt` - Raspberry Pi boot config
- `cmdline.txt` - Kernel command line parameters
- `BOOT-CONFIG.md` - Documentation for console-only mode

## Key Features

- **Console-only boot** (multi-user.target, no GUI)
- **Policy routing** with automatic failover (prague0 ↔ tailscale0)
- **"Chain of Irresponsibility" DNS** - 3 dnsmasq instances with hierarchical forwarding
  - Master resolver (127.0.0.1) holds static hosts + central cache
  - Edge instances (wlan0, eth1) serve DHCP leases + forward to master
  - Split domain forwarding (asusnet, raspinet, tailscale)
- **Kill switch** prevents traffic leaks when VPN fails
- **MSS clamping** for MTU 1380 WireGuard tunnel
- **Automated backups** with rsnapshot (30-day retention)
- **NetworkManager dispatcher** for automatic interface routing

## Sensitive Data

The following have been **REDACTED**:
- WireGuard private key in `wireguard/prague0.conf`
- WiFi hotspot password in `NetworkManager/system-connections/hotspot.nmconnection`
