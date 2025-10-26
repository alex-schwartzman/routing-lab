# asusrouter Configuration Backup

ASUS router running OpenWRT 24.10.2 (ramips/mt7621 - MIPS)

## Contents

### Network Configuration
- `config/network` - Interfaces, WireGuard, routing rules (WG key redacted)
- `config/firewall` - Firewall zones, NAT, MSS clamping, DNS rule
- `config/dhcp` - dnsmasq DNS/DHCP configuration (domain: asusnet)
- `config/wireless` - WiFi AP configuration (passwords redacted)
- `config/system` - System settings (hostname, timezone)
- `config/mini-mwan` - WAN/surfshark0 failover configuration

### System Configuration
- `hosts` - Local hostname mappings
- `iproute2/rt_tables` - Routing table definitions
- `sysctl.d/11-nf-conntrack.conf` - Connection tracking tuning

## Key Features

- **Dual-WAN failover**: Primary via dyckymost (wan), backup via surfshark0 (WireGuard)
- **Split DNS**: Local domain `asusnet`, forwards `raspinet` and `tail55bdec.ts.net` to dyckymost
- **WireGuard**: Backup tunnel to Surfshark Czech Republic (surfshark0)
- **MSS clamping**: Automatic MTU fixing for WireGuard
- **IPv6 disabled**: System-wide via sysctl
- **Firewall**: DNS allowed from wan (dyckymost), SSH/HTTP open

## Network Topology

```
asusrouter (192.168.10.1/24)
  ↓ wan (192.168.68.158)
dyckymost (192.168.68.1)
  ↓ tailscale0 → Internet (primary)
  
Backup path when dyckymost fails:
asusrouter → surfshark0 (WireGuard) → Internet
```

## Sensitive Data

The following have been **REDACTED**:
- WireGuard private key in `config/network`
- WiFi passwords (both 2.4GHz and 5GHz) in `config/wireless`
