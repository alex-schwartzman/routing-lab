# Poor Man's Mobile Failover Stealth VPN (2025 Edition)

**Total Budget:** ~125 EUR (~3,100 CZK)
**Philosophy:** Maximum redundancy, minimum cost
**Stealth Factor:** Multi-layer VPN with policy-based routing and kill switches

---

## Overview

This repository contains a snapshot (as of 2025) of a budget-friendly, multi-layer VPN failover setup designed for maximum uptime even when funds are tight. The system provides **three layers of hardware failover** using second-hand and refurbished equipment, all sourced for under 45 EUR each.

The network uses advanced Linux routing (policy routing, multiple VPN tunnels, automatic failover) to ensure connectivity even when individual components fail. The configuration emphasizes **privacy** (kill switches), **redundancy** (multiple failover paths), and **portability** (battery-powered backup with 4G).

---

## Hardware Components

### Layer 1: dyckymost (Main Router)
**Device:** Raspberry Pi 4 Kit
**Cost:** 1,000 CZK (~40 EUR)
**Source:** Second-hand marketplace
**Included:** Raspberry Pi 4 Model B, case, MicroSD card, power supply

**Role:**
- Primary VPN gateway (WireGuard + Tailscale)
- WiFi hotspot (2.4GHz, SSID: 🇨🇿𝔪𝔬𝔰𝔱🏰)
- Policy routing with automatic failover
- Backup system (rsnapshot, 30-day retention)

**Why it's cheap:** Bought second-hand Raspberry Pi kit in original box. Complete kit with everything included. Apparently no special cooling is required when running WireGuard or Tailscale up to 100Mbps. As soon as my ISP offers 500Mbps and as soon as I really need that throughput - I will need to spend 400 CZK (~16 EUR) on a case with active cooling.

---

### Layer 2: asusrouter (Backup Router)
**Device:** ASUS Router (MIPS-based, ramips/mt7621)
**Cost:** 1,000 CZK (~40 EUR)
**Source:** Alza (refurbished - customer return with discount)
**Firmware:** OpenWRT 24.10.2 (flashed from stock)

**Role:**
- LAN router for primary devices (MacBook, iPhone, etc.)
- Independent WireGuard tunnel (backup path)
- Dual-WAN failover (primary via dyckymost, backup via local WireGuard)
- Operates standalone when dyckymost fails

**Why it's cheap:** Refurbished unit (someone tried it and returned it, sold at discount)

---

### Layer 3: sweet (Mobile Backup)
**Device:** Xiaomi Redmi Note 10 Pro (codename: "sweet")
**Cost:** 1,100 CZK (~45 EUR)
**Source:** Second-hand marketplace
**Condition:** Frontal camera broken (known BGA issue with lead-free solder on older Xiaomi)

**Role:**
- Battery-powered WiFi hotspot (4G → WiFi)
- WiFi repeater (WiFi → WiFi, like GL-iNet Opal)
- Portable backup when both routers fail
- Tailscale VPN client (rooted Android)
- Can leech on public WiFi (Starbucks, IKEA, etc.)

**Why it's cheap:** Hardware defect (broken front camera) drastically reduced price, but the Qualcomm SM7150 Snapdragon 732G chipset is still excellent for Poly1305-ChaCha20 encryption thanks to ARM NEON vector instructions.

**Note:** The device is called "sweet" because "sweet" is the device codename Xiaomi uses for Redmi Note 10 Pro in kernel and device trees, ROM builds, and firmware repositories

---

## Failover Strategy

The network provides **layered redundancy** with multiple fallback paths:

### Normal Operation
```
Client devices → asusrouter → dyckymost → Tailscale exit node → Internet
WiFi clients → dyckymost hotspot → WireGuard (Czech Republic) → Internet
```

### Failover Scenario 1: asusrouter fails
**Action:** Connect directly to dyckymost WiFi hotspot (🇨🇿𝔪𝔬𝔰𝔱🏰)
**Result:** Devices now use WireGuard tunnel via dyckymost
**Downtime:** ~30 seconds (manual WiFi reconnect)

### Failover Scenario 2: dyckymost fails
**Action:** Connect asusrouter directly to ISP uplink, go to mini-mwan LuCI interface and remove wan from failover list
**Result:** asusrouter uses local WireGuard tunnel (surfshark0)
**Downtime:** ~2 minutes (cable reconnect + LuCI reconfiguration)

### Failover Scenario 3: Both dyckymost AND asusrouter fail
**Action:** Use sweet as WiFi hotspot or repeater
**Result:**
- **Option A:** sweet in Mobile Hotspot mode (4G SIM → WiFi)
- **Option B:** sweet in WiFi Repeater mode (ISP blackbox WiFi → WiFi hotspot)
- **Option C:** Portable mode (leech on Starbucks/IKEA WiFi, share via Tailscale)

**Downtime:** ~5 minutes (boot sweet, configure hotspot)

### Failover Scenario 4: ISP fails
**Action:** sweet switches from WiFi repeater to 4G mobile hotspot
**Result:** All traffic flows via 4G SIM card
**Downtime:** ~1 minute (automatic SIM failover on Android)

---

## Key Features

### Privacy & Security
- **Kill switches** on both routers (no traffic leaks when VPN fails)
- **MSS clamping** (prevents MTU blackhole issues)
- **Policy routing** (different traffic classes use different VPN tunnels)
- **Split DNS** (prevents DNS leaks, forwards Tailscale domains correctly)
- **No IPv6** (simplified routing, no IPv6 leaks)

### Redundancy
- **3 independent VPN paths:**
  - dyckymost: Tailscale (primary) + WireGuard (backup)
  - asusrouter: WireGuard (independent tunnel)
  - sweet: Tailscale + 4G mobile
- **4 network uplinks:**
  - ISP fiber (primary)
  - dyckymost failover routing
  - asusrouter local WireGuard
  - sweet 4G SIM

### Portability
- **sweet** is battery-powered and can operate standalone
- Can be used as portable VPN hotspot (attach to public WiFi, share via Tailscale)
- Useful for travel, cafes, or emergency backup

### Performance
- **dyckymost:** 100/150 Mbps (WireGuard) or 100/100 Mbps (Tailscale)
- **asusrouter:** 80/120 Mbps (limited by MIPS CPU encryption overhead)
- **sweet:** ~8 Mbps (4G) or ~20 Mbps (WiFi repeater, 2.4GHz → 5GHz)

---

## Repository Contents

### `/dyckymost/`
Configuration backup for Raspberry Pi 4 (main router)
- WireGuard tunnel config (key redacted)
- nftables firewall (NAT, kill switch, MSS clamping)
- NetworkManager hotspot config (password redacted)
- Policy routing scripts
- Backup system (rsnapshot)

### `/asusrouter/`
Configuration backup for ASUS router (backup router)
- OpenWRT UCI configs (network, firewall, DHCP, wireless)
- WireGuard backup tunnel (key redacted)
- Mini-MWAN failover config
- Split DNS configuration

### `/NETWORK-TOPOLOGY.md`
Comprehensive technical documentation:
- Network diagram and IP addressing
- Routing tables and policy routing rules
- WireGuard/Tailscale configuration details
- Firewall rules (nftables)
- DNS configuration (split DNS)
- Failure mode testing results
- Troubleshooting guide

### `/LICENSE`
GNU General Public License v3.0

---

## Quick Start

### 1. Deploy dyckymost (Raspberry Pi)
```bash
# Copy configs to Raspberry Pi
sudo cp dyckymost/wireguard/prague0.conf /etc/wireguard/
sudo cp dyckymost/nftables.conf /etc/
sudo cp -r dyckymost/NetworkManager/* /etc/NetworkManager/

# Start services
sudo systemctl enable --now nftables
sudo wg-quick up prague0
nmcli connection up hotspot
```

### 2. Deploy asusrouter (OpenWRT)
```bash
# SSH to router
ssh root@192.168.10.1

# Copy configs
scp asusrouter/config/* root@192.168.10.1:/etc/config/

# Reload configs
/etc/init.d/network reload
/etc/init.d/firewall reload
```

### 3. Deploy sweet (Android)
```bash
# Unlock bootloader and reflash to AOSP
# You will lose all security features of Android, but you'll get all the hardware control
# Provided that it is not your mobile phone anymore, but just a router with display
# which stays in the drawer, it is an acceptable compromise

# Install Tailscale (available as downloadable APK, from Aurora Store, or from F-Droid)
# Configure as exit node or regular client
```

---

## Testing Failover

### Test 1: Simulate dyckymost failure
```bash
# On dyckymost
sudo systemctl stop tailscaled
sudo wg-quick down prague0

# On client
# Connect to asusrouter WiFi
# Verify traffic uses asusrouter's surfshark0 tunnel
curl https://api.ipify.org
```

### Test 2: Simulate both routers failing
```bash
# Power off dyckymost and asusrouter
# Enable sweet hotspot
# Connect client to sweet WiFi
# Verify traffic uses Tailscale or 4G
```

---

## Cost Breakdown

| Device      | Cost (CZK) | Cost (EUR) | Source          | Condition       |
|-------------|------------|------------|-----------------|-----------------|
| dyckymost   | 1,000      | ~40        | Second-hand     | Complete kit    |
| asusrouter  | 1,000      | ~40        | Alza            | Refurbished     |
| sweet       | 1,100      | ~45        | Second-hand     | Broken camera   |
| **TOTAL**   | **3,100**  | **~125**   | -               | -               |

**Additional costs (optional):**
- Surfshark VPN: ~1 EUR/month (sometimes they do offer heavy discounts if you sign up for 3 years)
- Tailscale: Free tier (personal use)
- 4G SIM card: ~10 EUR/month (prepaid, backup only)

---

## Why "Poor Man's" VPN?

This setup demonstrates that robust, redundant VPN infrastructure doesn't require expensive enterprise hardware:

1. **Second-hand is sufficient:** Raspberry Pi kits and routers work great for VPN routing
2. **Defective = discount:** Broken front camera doesn't affect networking (sweet)
3. **Refurbished saves money:** Customer returns often have nothing wrong (asusrouter)
4. **Software > hardware:** Advanced routing (policy routing, failover) is free (Linux kernel)
5. **Multiple cheap > one expensive:** 3 devices at 40 EUR each > 1 device at 200 EUR

**Total cost for triple-redundant VPN setup:** Less than a single consumer VPN router (~250 EUR)

---

## Real-World Use Cases

### Use Case 1: ISP Outage
- ISP fiber goes down at 2 AM
- sweet automatically switches to 4G SIM
- Devices reconnect to sweet hotspot
- Downtime: ~5 minutes (manual WiFi reconnect)

### Use Case 2: Router Failure
- dyckymost SD card corrupts
- asusrouter continues operating with local WireGuard tunnel
- No reconfiguration needed (automatic failover via routing metrics)
- Downtime: 0 seconds (seamless failover)

### Use Case 3: Travel
- Take sweet to cafe
- Connect to cafe WiFi
- Enable Tailscale
- Share VPN connection via sweet hotspot
- Laptop/tablet connects to sweet, gets secure tunnel

### Use Case 4: Privacy-Critical Scenario
- Need to ensure VPN is active
- Kill switch prevents leaks if VPN fails
- Policy routing ensures WiFi clients ONLY use WireGuard
- No direct ISP access possible (nftables blocks it)

---

## Performance Notes

### Bottlenecks
- **asusrouter:** MIPS CPU limits WireGuard to ~80/120 Mbps
- **dyckymost:** Raspberry Pi 4 handles 100/150 Mbps easily
- **sweet:** 4G limited to ~8 Mbps (depends on carrier), WiFi repeater limited to ~20 Mbps (2.4GHz → 5GHz bottleneck)

### Optimizations
- **MSS clamping:** Prevents MTU blackhole (essential for WireGuard)
- **ChaCha20-Poly1305:** Faster than AES on ARM/MIPS without hardware acceleration. Critical for battery life on sweet - 20x less CPU usage means 20x more traffic we can handle on a single charge.
- **Policy routing:** Different traffic classes use optimal paths
- **Connection tracking tuning:** Increased limits on asusrouter (MIPS has less RAM)

---

## Future Enhancements

**Potential improvements (when budget allows - all under 100 CZK):**

1. **Active cooling for dyckymost:** Case with fan (~200-400 CZK) in case if ISP upgrades me to 500Mbps and in case if I really need that thoughput
2. **Domain-based policy routing:** Fetch sensitive data via Tailscale, and bulky bigger docker downloads via WireGuard.


---

## Known Limitations

1. **Manual failover:** Switching between layers requires manual WiFi reconnect
2. **sweet battery life:** ~8 hours as hotspot (1 day standby)
3. **4G data cap:** Depends on SIM plan (not suitable for docker and youtube lectures)
4. **asusrouter CPU:** MIPS bottleneck limits VPN speed to ~80 Mbps
5. **No automatic VPN restart:** Policy routing provides failover, but doesn't restart failed tunnels

---

## Documentation

For detailed technical documentation, see:
- **[NETWORK-TOPOLOGY.md](NETWORK-TOPOLOGY.md)** - Complete network architecture, routing, firewall rules
- **[dyckymost/README.md](dyckymost/README.md)** - Raspberry Pi configuration details
- **[asusrouter/README.md](asusrouter/README.md)** - OpenWRT configuration details

---

## License

This configuration snapshot is released under the **GNU General Public License v3.0**.

You are free to:
- Use this configuration for personal or commercial purposes
- Modify and adapt it to your needs
- Share it with others

See [LICENSE](LICENSE) for full terms.

---

## Credits

**Configuration:** Claude (Anthropic) + slavibor
**Date:** October 2025
**Network Owner:** slavibor

**Special Thanks:**
- WireGuard team (amazing VPN protocol)
- Tailscale team (zero-config mesh VPN)
- OpenWRT community (router firmware)
- Surfshark (affordable multi-hop VPN)
- Civil engineers of Most, Czech Republic (for building best-in-class city infrastructure and city layout, which inspires to never stop at "good infrastructure" and strive to constantly improve it)

---

## Support

This is a personal configuration snapshot, not a supported product. Use at your own risk.

For technical questions:
1. Read [NETWORK-TOPOLOGY.md](NETWORK-TOPOLOGY.md) first
2. Check the troubleshooting section
3. Adapt the configuration to your environment

**Useful resources:**
- WireGuard: https://www.wireguard.com/
- Tailscale: https://tailscale.com/
- OpenWRT: https://openwrt.org/
- nftables: https://wiki.nftables.org/

---

## Philosophy

> "The best failover setup is the one you can actually afford to deploy."

This project proves that:
- **Redundancy doesn't require wealth** (3 layers for 125 EUR)
- **Second-hand is underrated** (perfectly fine for routing)
- **Software beats hardware** (policy routing is free, enterprise routers are not)
- **Broken can be beautiful** (sweet's broken camera = 70% discount)

**Total budget:** Less than two months of typical enterprise VPN subscription.
**Result:** Triple-redundant, privacy-focused, portable VPN infrastructure.

---

*README.md - Last updated: 2025-10-27*
