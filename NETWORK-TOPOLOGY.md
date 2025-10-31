# Network Topology & Configuration Documentation

**Last Updated:** 2025-10-29
**Status:** Fully operational with DNS "Chain of Irresponsibility" architecture

---

## Network Overview

**Linear Topology:**
```
┌─────────────────┐
│   asusrouter    │ OpenWRT 24.10.2
│ 192.168.10.1/24 │ LAN clients (Hostimil, Bolemir, etc)
└────────┬────────┘
         │ wan: 192.168.68.158/24
         │
┌────────▼────────────────────────────────────────────┐
│                  dyckymost                          │
│          Raspberry Pi 4 Model B Rev 1.5             │
│                                                     │
│  eth1: 192.168.68.1/24  (to asusrouter)            │
│  eth0: 192.168.1.38/24  (to blackbox)              │
│  wlan0: 192.168.54.1/24 (WiFi hotspot 🇨🇿𝔪𝔬𝔰𝔱🏰)     │
│  tailscale0: 100.111.185.23/32                     │
│  prague0: 10.14.0.2/16 (WireGuard to CZ)           │
└────────┬────────────────────────────────────────────┘
         │ eth0: 192.168.1.38/24
         │
┌────────▼────────┐
│    blackbox     │ ISP Gateway
│  192.168.1.1    │
└─────────────────┘

Traffic Paths:
──────────────
• asusrouter clients → eth1 → tailscale0 → Internet
  (failover: → prague0 if tailscale down)

• dyckymost wlan0 clients → prague0 → Internet 🇨🇿
  (failover: → tailscale0 if prague down)

• asusrouter → surfshark0 (local WG) if both dyckymost tunnels fail
```

---

## Device Details

### dyckymost (Main Router)

**Hardware:** Raspberry Pi 4 Model B Rev 1.5
**OS:** Debian GNU/Linux 12 (bookworm) / Kernel 6.12.47
**Access:** `ssh slavibor@192.168.54.1` (via wlan0 hotspot)

#### Network Interfaces

| Interface   | IP Address        | Description                          |
|-------------|-------------------|--------------------------------------|
| eth0        | 192.168.1.38/24   | Uplink to blackbox (ISP gateway 192.168.1.1) |
| eth1        | 192.168.68.1/24   | Downlink to asusrouter (wan: 192.168.68.158) |
| wlan0       | 192.168.54.1/24   | WiFi hotspot for clients            |
| tailscale0  | 100.111.185.23/32 | Tailscale VPN (default exit)        |
| prague0     | 10.14.0.2/16      | WireGuard to Surfshark CZ-Prague    |

#### WireGuard Configuration

**Tunnel:** `prague0`
**Config:** `/etc/wireguard/prague0.conf`
**Endpoint:** `cz-prg.prod.surfshark.com:51820` (currently: 185.242.6.93)
**MTU:** 1380 bytes
**Tunnel IP:** 10.14.0.2/16
**Peer Public Key:** `c1bfP+OBTj6WUe8NDH8d6nDTwpQicopfdkHFx3BIaSk=`
**Allowed IPs:** 0.0.0.0/0

**Management:**
```bash
sudo wg-quick up prague0
sudo wg-quick down prague0
sudo wg show prague0
```

#### Tailscale Configuration

**IP:** 100.111.185.23/32
**Exit Node:** 100.112.56.95
**Flags:** `--ssh --accept-dns=false --accept-routes --exit-node=100.112.56.95`
**MagicDNS Domain:** tail55bdec.ts.net

**Key Detail:** Tailscale marks its egress packets with SO_MARK (0x80000), which is used in routing rules to prevent conflicts.

#### WiFi Hotspot

**SSID:** 🇨🇿𝔪𝔬𝔰𝔱🏰
**Interface:** wlan0
**IP:** 192.168.54.1/24
**DHCP Range:** 192.168.54.10 - 192.168.54.254
**Security:** WPA2-PSK (CCMP)
**Band:** 5GHz (802.11a)
**Config:** `/etc/NetworkManager/system-connections/hotspot.nmconnection`

**dnsmasq for hotspot:**
- Managed by NetworkManager
- Provides DHCP + DNS for 192.168.54.0/24

---

## Routing Architecture

### Routing Tables

**View all tables:**
```bash
cat /etc/iproute2/rt_tables
```

| ID  | Name      | Purpose                                    |
|-----|-----------|--------------------------------------------|
| 254 | main      | Default eth0 route (192.168.10.1)         |
| 253 | default   | System default                             |
| 53  | prague    | WireGuard tunnel routes                    |
| 52  | tailscale | Tailscale exit node routes                 |

### Policy Routing Rules

**View all rules:**
```bash
ip rule show
```

| Priority | Rule                                  | Action          | Purpose                           |
|----------|---------------------------------------|-----------------|-----------------------------------|
| 0        | from all                              | lookup local    | Local traffic                     |
| 100      | from all to 192.168.1.0/24           | lookup main     | Keep blackbox subnet local (eth0) |
| 100      | from all to 192.168.10.0/24          | lookup main     | Keep asusrouter subnet local (eth1) |
| 100      | from all to 192.168.54.0/24          | lookup main     | Keep hotspot traffic local (wlan0)|
| 100      | from all to 192.168.68.0/24          | lookup main     | Keep eth1 subnet local            |
| 105      | from all fwmark 0x100000/0xff0000    | lookup main     | WireGuard handshake packets       |
| 5210     | from all fwmark 0x80000/0xff0000     | lookup main     | Tailscale fwmark → main           |
| 5230     | from all fwmark 0x80000/0xff0000     | lookup default  | Tailscale fwmark → default        |
| 5250     | from all fwmark 0x80000/0xff0000     | unreachable     | Tailscale fwmark blackhole        |
| 5260     | from 192.168.54.0/24                 | lookup prague   | WiFi clients → prague0 (PRIMARY)  |
| 5270     | from all                              | lookup tailscale| Default → tailscale0              |
| 5270     | from 192.168.1.38                     | lookup tailscale| Local traffic → tailscale (PRIMARY) |
| 5280     | from 192.168.1.38                     | lookup prague   | Local traffic → prague0 (FAILOVER) |
| 5290     | from 192.168.1.38                     | unreachable     | Local traffic kill switch         |
| 32766    | from all                              | lookup main     | Fallback                          |
| 32767    | from all                              | lookup default  | Final fallback                    |

### Routing Table Contents

**prague table:**
```bash
ip route show table prague
# Output: default dev prague0 proto prague-wg scope link metric 600
```

**tailscale table:**
```bash
ip route show table tailscale
# Output: default dev tailscale0
#         100.x.x.x routes...
```

**main table:**
```bash
ip route show table main
# Output: default via 192.168.1.1 dev eth0 proto dhcp
#         10.14.0.0/16 dev prague0 proto kernel
#         192.168.1.0/24 dev eth0 proto kernel
#         192.168.54.0/24 dev wlan0 proto kernel
#         192.168.68.0/24 dev eth1 proto kernel
```

### Custom Route Protocol

**File:** `/etc/iproute2/rt_protos`
**Custom Proto:** `17    prague-wg`

**Purpose:** Track WireGuard-related routes for auditing.

**Audit routes:**
```bash
ip route show proto prague-wg
# Shows only routes added by WireGuard setup
```

### Policy Routing Failover Mechanism

The network uses **policy routing-based failover**, not automatic VPN failover. The Linux kernel tries each routing rule in priority order until it finds a working route.

**Failover Scenario 1: prague0 (WireGuard) fails**
```
WiFi client (192.168.54.119) sends packet to Internet
  ↓
Priority 5260: from 192.168.54.0/24 lookup prague
  ↓ Route in prague table points to prague0
  ↓ prague0 is DOWN → Route lookup FAILS
  ↓
Kernel continues to next matching rule...
  ↓
Priority 5270: from all lookup tailscale
  ↓ Route in tailscale table points to tailscale0
  ↓ tailscale0 is UP → SUCCESS ✓
  ↓
Traffic flows via tailscale0
```

**Failover Scenario 2: tailscale0 fails**
```
Non-WiFi traffic (default traffic) to Internet
  ↓
Priority 5270: from all lookup tailscale
  ↓ Route in tailscale table points to tailscale0
  ↓ tailscale0 is DOWN → Route lookup FAILS
  ↓
Kernel continues to next matching rule...
  ↓
Priority 5280: from all lookup prague
  ↓ Route in prague table points to prague0
  ↓ prague0 is UP → SUCCESS ✓
  ↓
Traffic flows via prague0
```

**Failover Scenario 3: Both prague0 AND tailscale0 fail**
```
WiFi client traffic
  ↓
Priority 5260: lookup prague → FAILS (prague0 down)
Priority 5270: lookup tailscale → FAILS (tailscale0 down)
Priority 5280: lookup prague → FAILS (prague0 down)
Priority 5300: lookup prague → FAILS (prague0 down)
  ↓
Kill switch in nftables blocks direct eth0 access
  ↓
WiFi clients LOSE CONNECTIVITY (by design - privacy protection)
```

**Key Points:**
- **No automatic VPN restart** - failover happens at routing table lookup level
- **Priority-based** - kernel tries rules in order (lower number = higher priority)
- **Redundant rules** - Multiple prague table lookups (5280, 5300) ensure failover
- **Kill switch enforced** - nftables prevents WiFi clients from leaking via eth0 when both VPNs fail

---

## Traffic Flow & Routing Logic

### Flow Decision Tree

```
Packet arrives on dyckymost
│
├─ Destination: Local subnet (192.168.1.0/24, 192.168.10.0/24, 192.168.54.0/24, 192.168.68.0/24)?
│  └─ YES → main table → eth0, eth1, or wlan0 (local delivery)
│
├─ Source: 192.168.54.0/24 (WiFi clients)?
│  └─ YES → prague table → prague0 → WireGuard → eth0 → Internet 🇨🇿
│       (If prague0 down → tailscale table → tailscale0)
│
├─ Packet: WireGuard UDP (port 51820) with fwmark 0x100000?
│  └─ YES → main table → eth0 (prevent routing loop)
│
└─ DEFAULT → tailscale table → tailscale0 → Exit Node → Internet
        (If tailscale0 down → prague table → prague0)
```

### Detailed Traffic Paths

#### WiFi Client (sweet) → Internet

```
sweet (192.168.54.119)
  ↓ wlan0 (WiFi)
dyckymost receives packet
  ↓ Policy routing: rule 5260 (from 192.168.54.0/24 → table prague)
  ↓ NAT: 192.168.54.119 → 10.14.0.2 (masquerade)
  ↓ MSS clamping: TCP MSS → 1340 bytes
prague0 (WireGuard tunnel)
  ↓ Encryption + WireGuard overhead
  ↓ Wrapped in UDP to 185.242.6.93:51820
eth0 (192.168.10.197)
  ↓ Uplink to ISP
Internet 🇨🇿 (via Surfshark Czech Republic)
```

#### WireGuard Handshake Packets (Special Case)

```
Application sends to prague0
  ↓
nftables marks UDP port 51820 with fwmark 0x100000
  ↓ Policy routing: rule 105 (fwmark 0x100000 → table main)
  ↓ NAT: masquerade on eth0
eth0 → 185.242.6.93:51820
  ↓
Internet (WireGuard server)
```

**Why this is needed:** Without this, WireGuard handshake packets would be routed via tailscale0 or prague0 (routing loop!).

#### Default Traffic (asusrouter clients via eth1) → Internet

```
Client on asusrouter LAN (192.168.10.x)
  ↓ asusrouter br-lan (192.168.10.1)
  ↓ asusrouter wan (192.168.68.158)
dyckymost eth1 (192.168.68.1) receives packet
  ↓ Policy routing: rule 5270 (from all → table tailscale)
tailscale0 (VPN tunnel)
  ↓ Exit node: 100.112.56.95
Internet (via Tailscale exit node)
```

**Failover path when tailscale0 fails:**
```
Priority 5270: lookup tailscale → FAILS (tailscale0 down)
Priority 5280: lookup prague → prague0 UP ✓
  ↓
Traffic flows via prague0 (WireGuard to Czech Republic)
```

---

## Firewall Configuration (nftables)

**Config File:** `/etc/nftables.conf`
**Service:** `nftables.service` (enabled at boot)

**View active rules:**
```bash
sudo nft list ruleset
```

**Reload configuration:**
```bash
sudo nft -f /etc/nftables.conf
```

### MSS Clamping (MTU Fix)

**Problem:** WireGuard MTU is 1380 bytes, but clients try to send 1500-byte packets → fragmentation/blackhole.

**Solution:** TCP MSS clamping rewrites SYN packets to limit segment size.

**Rules:**
```nft
table inet mangle {
    chain forward {
        type filter hook forward priority mangle; policy accept;

        # Outbound: Client → Internet via prague0
        oifname "prague0" tcp flags syn tcp option maxseg size set 1340 counter comment "MSS clamp outbound prague0"

        # Inbound: Internet → Client via prague0
        iifname "prague0" tcp flags syn tcp option maxseg size set 1340 counter comment "MSS clamp inbound prague0"
    }
}
```

**Calculation:** MSS = MTU - 40 (20 bytes IP header + 20 bytes TCP header)
**MTU 1380 → MSS 1340**

### WireGuard Packet Marking

**Purpose:** Mark WireGuard packets (UDP port 51820) so they route via eth0, not via Tailscale or prague0 (avoid loops).

**WireGuard FwMark (Locally Generated):**
Set in `/etc/wireguard/prague0.conf`:
```ini
FwMark = 0x100000
```
This marks packets **at socket creation** before routing decision, ensuring WireGuard protocol packets from dyckymost itself always route via main table → eth0.

**Mangle PREROUTING (Forwarded from eth1):**
```nft
table inet mangle {
    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        iifname "eth1" udp dport 51820 meta mark set 0x00100000 counter comment "Mark eth1 WG traffic"
    }
}
```
Marks forwarded WireGuard traffic from eth1 (asusrouter clients) **at mangle priority** (before conntrack NAT) to route via main table → eth0 directly, bypassing Tailscale.

**fwmark:** 0x100000 (used in `ip rule` priority 105)

**Why mangle priority?** Marking at mangle priority (-150) happens **before** conntrack NAT processing (-100), preventing interference with NAT state tracking. Previous implementation marked packets at NAT priority (dstnat), which caused conntrack conflicts resulting in every-second-packet drops.

### NAT / Masquerading

**Purpose:**
1. Masquerade WiFi clients (192.168.54.x) to WireGuard tunnel IP (10.14.0.2)
2. Masquerade WireGuard handshakes on eth0

**Rules:**
```nft
table ip nat {
    chain POSTROUTING {
        type nat hook postrouting priority srcnat; policy accept;

        # WireGuard handshake packets going to eth0
        meta mark & 0x00f00000 == 0x00100000 oifname "eth0" udp dport 51820 counter masquerade comment "NAT-wg-handshake"

        # All traffic going through prague0 tunnel
        oifname "prague0" counter masquerade comment "NAT-prague0"
    }
}
```

**Effect:**
- Without NAT: `192.168.54.119 → 1.1.1.1` (Internet doesn't know how to route back)
- With NAT: `10.14.0.2 → 1.1.1.1` (routable via WireGuard)

### Forward Chain (Kill Switch)

**Purpose:**
1. Allow WiFi/eth1 clients to use prague0 (WireGuard)
2. Block direct access to eth0 (kill switch)
3. Allow only WireGuard handshakes to eth0

**Rules:**
```nft
table inet filter {
    chain forward {
        type filter hook forward priority filter; policy accept;

        # Allow established connections
        ct state established,related counter accept

        # Allow WiFi and eth1 → prague0 (WireGuard tunnel)
        iifname "wlan0" oifname "prague0" counter accept
        iifname "eth1" oifname "prague0" counter accept

        # Allow return traffic
        iifname "prague0" oifname "wlan0" counter accept
        iifname "prague0" oifname "eth1" counter accept

        # Allow WireGuard handshakes → eth0
        iifname "wlan0" oifname "eth0" udp dport 51820 counter accept
        iifname "eth1" oifname "eth0" udp dport 51820 counter accept

        # KILL SWITCH: Drop everything else to eth0
        iifname "wlan0" oifname "eth0" counter drop
        iifname "eth1" oifname "eth0" counter drop
    }
}
```

**Effect:**
- WiFi clients can ONLY reach Internet via prague0 (WireGuard)
- If WireGuard fails → no leak via eth0 (kill switch protects privacy)

---

## DNS Configuration

### Architecture: "Chain of Irresponsibility" Pattern

NetworkManager runs **three separate dnsmasq instances** on dyckymost, implementing a hierarchical DNS architecture where edge servers delegate to a central resolver.

**Key Design Decision:** NetworkManager provides `--conf-dir` for each dnsmasq instance but doesn't allow per-interface configs. Both wlan0 and eth1 read from the same `dnsmasq-shared.d/` directory, making it impossible to have different authoritative zones per interface.

### Domain-to-Network Authoritative Mapping

**⚠️ Important:** The `.raspinet` domain has **split authority** across two separate networks, each with its own authoritative DNS server. This is architecturally irregular but functionally acceptable.

| Domain | Network | Authoritative DNS | DHCP Server | Primary Devices |
|--------|---------|-------------------|-------------|-----------------|
| **asusnet** | 192.168.10.0/24 | 192.168.10.1 (asusrouter) | asusrouter | Hostimil, Bolemir, LAN clients |
| **raspinet** (primary) | 192.168.54.0/24 | 192.168.54.1 (dyckymost wlan0) | dyckymost wlan0 | WiFi hotspot clients, mobile devices |
| **raspinet** (hidden) | 192.168.68.0/24 | 192.168.68.1 (dyckymost eth1) | dyckymost eth1 | asusrouter WAN interface only |

**Split Authority Implications:**

- **asusnet**: Clean single authority - asusrouter dnsmasq knows all DHCP clients on 192.168.10.0/24
- **raspinet (primary)**: 192.168.54.1 serves WiFi clients - this is the "main" `.raspinet` zone
- **raspinet (hidden)**: 192.168.68.0/24 shares the `.raspinet` domain but is isolated:
  - Only asusrouter.raspinet exists here (single DHCP client)
  - Clients on 192.168.54.0/24 **cannot** resolve names from 192.168.68.0/24
  - This segment is effectively "hidden" from the primary raspinet zone
  - Considered **unusable for general DHCP clients** due to domain overlap

**Why This Configuration:**

NetworkManager's constraint (shared `dnsmasq-shared.d/` config for both wlan0 and eth1) prevents assigning different domains per interface. Both must use `domain=raspinet`, creating split authority.

**Design Decision:** Accept the limitation. The eth1 network (192.168.68.0/24) is infrastructure-only (asusrouter WAN), so having limited DNS visibility is acceptable.

### Three dnsmasq Instances

#### 1. **127.0.0.1:53** - Master Resolver (Local Queries)
**Purpose:** DNS resolver for dyckymost itself and fallback for edge instances
**Config:** `/etc/NetworkManager/dnsmasq.d/split.conf`
**Clients:** dyckymost localhost, wlan0/eth1 dnsmasq instances (as upstream)

**Configuration:**
```conf
domain=raspinet

# Static infrastructure hosts (not DHCP clients)
host-record=dyckymost.raspinet,192.168.54.1
host-record=dyckymost,192.168.54.1

# Forward Tailscale domain to Tailscale DNS
server=/tail55bdec.ts.net/100.100.100.100

# Forward asusnet domain to asusrouter
server=/asusnet/192.168.68.158

# Default fallback public DNS
server=8.8.8.8
server=1.1.1.1

no-resolv
```

**Responsibilities:**
- Serves static `host-record` entries for infrastructure (dyckymost itself)
- Centralized cache for all internet DNS queries
- Forwards specialized domains (Tailscale, asusnet)
- Falls back to public DNS (8.8.8.8, 1.1.1.1)

#### 2. **192.168.54.1:53** - WiFi Hotspot (wlan0)
**Purpose:** DNS + DHCP server for WiFi clients
**Config:** `/etc/NetworkManager/dnsmasq-shared.d/split.conf`
**Clients:** WiFi hotspot clients (192.168.54.0/24)

**Configuration:**
```conf
domain=raspinet
server=127.0.0.1
no-resolv
```

**Responsibilities:**
- Serves DHCP leases for wlan0 (192.168.54.10-254)
- Resolves `.raspinet` names from its DHCP leases
- Forwards everything else → 127.0.0.1

#### 3. **192.168.68.1:53** - eth1 Network
**Purpose:** DNS + DHCP server for eth1 network (asusrouter)
**Config:** `/etc/NetworkManager/dnsmasq-shared.d/split.conf` (shared with wlan0)
**Clients:** eth1 network devices (192.168.68.0/24)

**Configuration:** Same as wlan0 (both use `dnsmasq-shared.d/`)

**Responsibilities:**
- Serves DHCP leases for eth1 (192.168.68.10-254)
- Resolves `.raspinet` names from its DHCP leases
- Forwards everything else → 127.0.0.1

### DNS Resolution Flow

**Example 1: WiFi client queries `google.com`**
```
Client (192.168.54.195)
  ↓ Query: google.com
192.168.54.1 (wlan0 dnsmasq)
  ↓ Not a DHCP lease → forward to 127.0.0.1
127.0.0.1 (master dnsmasq)
  ↓ Check cache → MISS
  ↓ Forward to 8.8.8.8
Google DNS
  ↓ Returns IP
127.0.0.1 caches result
  ↓
192.168.54.1 caches result
  ↓
Client receives IP
```

**Example 2: WiFi client queries `Hostimil.raspinet`**
```
Client (192.168.54.195)
  ↓ Query: Hostimil.raspinet
192.168.54.1 (wlan0 dnsmasq)
  ↓ Check DHCP leases → FOUND (192.168.54.195)
  ↓ Authoritative answer
Client receives IP (no upstream query needed)
```

**Example 3: dyckymost queries `Hostimil.raspinet`**
```
dyckymost localhost
  ↓ Query: Hostimil.raspinet
127.0.0.1 (master dnsmasq)
  ↓ Not in static hosts → not found
  ↓ Would fall through to 8.8.8.8 → NXDOMAIN
Client receives NXDOMAIN
```
**Note:** 127.0.0.1 cannot resolve DHCP clients from wlan0/eth1 because there's no forwarding from master to edge instances.

### Architectural Tradeoffs & Design Decisions

#### ✅ Benefits of "Chain of Irresponsibility"

1. **Centralized caching:** All internet DNS queries cached once at 127.0.0.1, shared benefit across all interfaces
2. **Single source of truth:** Static hosts defined in one config file (`dnsmasq.d/split.conf`)
3. **Simplified management:** Only edit localhost config for infrastructure changes
4. **Two-level caching:** Edge instances cache their own queries, master caches everything else

#### ❌ Limitations

1. **Single point of failure:** If 127.0.0.1 dnsmasq crashes, wlan0/eth1 lose internet DNS (hence "irresponsibility")
2. **Extra latency:** ~1-5ms added per query (minimal in practice, all local)
3. **No cross-interface DHCP resolution:** 127.0.0.1 cannot resolve DHCP clients from wlan0/eth1
4. **NetworkManager constraints:** Cannot assign different `conf-dir` per interface, limiting architectural options

#### Why Not Cross-Interface DNS Forwarding?

**Attempted approach:** Configure 127.0.0.1 to forward `.raspinet` queries to both 192.168.54.1 and 192.168.68.1.

**Why it failed:**
1. Without `local=/raspinet/`, edge instances forward unknown `.raspinet` queries to public DNS (8.8.8.8)
2. Public DNS returns NXDOMAIN, which 127.0.0.1 accepts without trying the next server
3. With `local=/raspinet/`, edge instances return **authoritative** NXDOMAIN immediately
4. 127.0.0.1 receives authoritative NXDOMAIN and stops (doesn't try next server)
5. dnsmasq's `all-servers` directive queries all servers but returns **first response** (race condition, not "first positive response")

**Conclusion:** NetworkManager's shared config directory + dnsmasq's forwarding semantics make cross-interface DHCP resolution architecturally impossible without running a custom dnsmasq instance.

#### Why Public DNS (8.8.8.8, 1.1.1.1) Over Surfshark DNS?

**Consideration:** Surfshark provides Prague-based DNS servers when using prague0 tunnel. Theoretically closer = faster.

**Decision:** Use anycast public DNS (Google, Cloudflare) instead.

**Reasoning:**
1. **Multi-WAN compatibility:** dyckymost has multiple exit points (prague0, tailscale0)
   - prague0 active → Surfshark Prague DNS optimal
   - tailscale0 active → Surfshark Prague DNS suboptimal (exit node could be anywhere)
2. **Anycast handles routing:** 8.8.8.8/1.1.1.1 automatically connect to nearest edge node regardless of exit point
3. **Latency difference minimal:** ~15-25ms extra from Prague vs Surfshark DNS (negligible)
4. **GeoDNS still works:** CDNs return nodes close to the exit point, not DNS server location
5. **Simplicity:** No need for dynamic DNS switching based on active tunnel

**Trade-off accepted:** Slightly higher DNS latency (~20-30ms vs ~5ms) for architectural simplicity and multi-WAN reliability.

### dnsmasq (on asusrouter)

**Managed by:** OpenWRT UCI
**Config:** `/etc/config/dhcp`

**Configuration:**
```conf
domain=asusnet
local=/asusnet/
authoritative=1
filter_aaaa=1
```

**DNS Resolution Flow (from asusrouter LAN clients):**
1. `*.asusnet` → dnsmasq local records (DHCP hostnames)
2. Everything else → upstream via wan (dyckymost) or Surfshark DNS

---

## Failure Mode Testing

The network has been tested under various failure scenarios to verify failover behavior and redundancy.

### Test 1: Tailscale Down on dyckymost

**Scenario:**
- `tailscale0` DOWN on dyckymost
- `wan` UP (eth0 to blackbox)
- `surfshark0` UP on asusrouter (unused, backup route)

**Result:**
- WiFi client (sweet) egress IP: **185.242.6.126**
- Traffic path: sweet → dyckymost wlan0 → prague0 (WireGuard) → eth0 → Internet
- Ookla speedtest: **100/150 Mbps** (download/upload)

**Behavior:** WiFi clients continue to use prague0 WireGuard tunnel on dyckymost. Tailscale unavailable but not needed for WiFi clients (isolated by policy routing).

---

### Test 2: Both Tunnels Down on dyckymost

**Scenario:**
- `tailscale0` DOWN on dyckymost
- `prague0` DOWN on dyckymost
- Kill switch activates (blocks direct wan access for wlan0 clients)
- `surfshark0` UP on asusrouter (automatically used as failover)

**Result:**
- asusrouter egress IP: **185.242.6.68**
- Traffic path: asusrouter clients → surfshark0 (WireGuard on asusrouter) → wan → dyckymost → Internet
- Ookla speedtest: **80/120 Mbps** (download/upload)

**Behavior:**
- dyckymost WiFi clients lose connectivity (kill switch blocks direct eth0 access)
- asusrouter clients automatically fail over to local surfshark0 WireGuard tunnel
- Performance limited by asusrouter CPU constraints (MIPS processor, encryption overhead)

**Note:** This scenario demonstrates that asusrouter can operate independently when dyckymost's tunnels fail.

---

### Test 3: Prague WireGuard Down, Tailscale Up

**Scenario:**
- `prague0` DOWN on dyckymost
- `tailscale0` UP on dyckymost
- WiFi clients no longer match policy rule (192.168.54.0/24 → prague table)

**Result:**
- Traffic egress IP: **ExitNodeIP**
- Traffic path: clients → tailscale0 (exit node 100.112.56.95) → Internet
- Ookla speedtest: **100/100 Mbps** (download/upload)

**Behavior:**
- When prague0 is unavailable, policy routing rule 5260 fails
- Traffic falls through to priority 5270 (lookup tailscale)
- **Policy routing-based failover** - kernel automatically tries next rule
- Seamless failover to tailscale0 exit node
- Symmetric bandwidth (100/100) characteristic of Tailscale exit node routing

---

### Failure Mode Summary

| Scenario | tailscale0 | prague0 | surfshark0 (asusrouter) | Egress IP | Speed (Down/Up) | Behavior |
|----------|------------|---------|------------------------|-----------|-----------------|----------|
| Normal   | UP         | UP      | UP (unused)            | 185.242.6.93 (prague0) | 100/150 Mbps | WiFi → prague0 |
| Tailscale Down | DOWN | UP      | UP (unused)            | 185.242.6.126 | 100/150 Mbps | WiFi → prague0 |
| Both Down | DOWN      | DOWN    | UP                     | 185.242.6.68 | 80/120 Mbps | asusrouter → surfshark0 |
| Prague Down | UP      | DOWN    | UP (unused)            | ExitNodeIP | 100/100 Mbps | WiFi → tailscale0 |

**Observations:**
1. **Policy routing failover:** Linux kernel automatically tries routing rules in priority order - no special VPN software needed
2. **Redundancy works:** Multiple failover paths (priorities 5280, 5300) ensure connectivity even with dual tunnel failures
3. **Kill switch enforced:** dyckymost WiFi clients cannot leak via direct eth0 when prague0 fails (nftables blocks)
4. **asusrouter independence:** Can operate standalone with its own WireGuard tunnel when dyckymost tunnels fail
5. **Performance:** Best performance via dyckymost tunnels (100/150 Mbps), reduced on asusrouter (80/120 Mbps, MIPS CPU-bound)
6. **Seamless failover:** Policy routing provides transparent failover - applications don't notice VPN changes

---

## IPv6 Status

**Status:** ✅ **DISABLED system-wide**

**Why:** Simplified routing, removed conflicts with Tailscale/WireGuard IPv6 handling.

**Configuration:**
```bash
# /etc/sysctl.conf or /etc/sysctl.d/*.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```

**NetworkManager connections:**
```bash
nmcli connection modify eth0 ipv6.method disabled
nmcli connection modify hotspot ipv6.method disabled
nmcli connection modify prague0 ipv6.method disabled
```

**Verify:**
```bash
cat /proc/sys/net/ipv6/conf/all/disable_ipv6
# Output: 1 (disabled)

ip -6 addr show
# Should only show ::1 on lo
```

---

## Backup System

**Tool:** rsnapshot
**Schedule:** Daily at midnight (cron)
**Retention:** 30 daily snapshots
**Location:** `/backup/daily.0/` (newest) to `/backup/daily.29/` (oldest)

**What's backed up:**
- `/etc` (all configuration)
- `/root` (root home directory)
- `/home/slavibor` (user home)
- `/var/spool/cron` (cron jobs)
- `/var/lib/backup-info/` (package lists, system info)

**Space efficiency:** Uses hard links (30 days ≈ 50-100 MB total)

**Config:** `/etc/rsnapshot.conf`
**Cron:** `/etc/cron.d/rsnapshot`

**Manual backup:**
```bash
sudo rsnapshot daily
```

**Disaster recovery (SD card on Hostimil):**
```bash
# Mount SD card
cd /Volumes/rootfs/backup/daily.0/localhost/

# Restore specific config
sudo cp -a etc/NetworkManager/* /Volumes/rootfs/etc/NetworkManager/

# Or restore from 5 days ago
cd /Volumes/rootfs/backup/daily.5/localhost/
sudo cp -a etc/* /Volumes/rootfs/etc/
```

---

## Troubleshooting Commands

### Check Routing

```bash
# Show all routing tables
ip route show table all

# Show specific table
ip route show table prague
ip route show table tailscale
ip route show table main

# Show policy routing rules
ip rule show

# Test route lookup from WiFi client IP
ip route get 1.1.1.1 from 192.168.54.119

# Show routes by protocol
ip route show proto prague-wg
```

### Check WireGuard

```bash
# Status
sudo wg show prague0

# Restart
sudo wg-quick down prague0
sudo wg-quick up prague0

# Check handshake
sudo wg show prague0 latest-handshakes
sudo wg show prague0 transfer

# Verify endpoint
sudo wg show prague0 endpoints
```

### Check Firewall

```bash
# Show all nftables rules
sudo nft list ruleset

# Show specific table/chain
sudo nft list table inet mangle
sudo nft list chain inet filter forward

# Check counters
sudo nft list chain inet filter forward | grep counter

# Reload config
sudo nft -f /etc/nftables.conf
```

### Check NAT / Masquerading

```bash
# Show NAT table
sudo nft list table ip nat

# Check conntrack entries
sudo conntrack -L
sudo conntrack -L -s 192.168.54.119

# Delete stale conntrack entries
sudo conntrack -D -s 192.168.54.119
```

### Packet Capture

```bash
# Capture on WireGuard tunnel
sudo tcpdump -i prague0 -n icmp

# Capture WireGuard handshakes on eth0
sudo tcpdump -i eth0 -n "udp port 51820"

# Capture WiFi client traffic
sudo tcpdump -i wlan0 -n "host 192.168.54.119"

# Verify NAT is working (should see 10.14.0.2, not 192.168.54.x)
sudo tcpdump -i prague0 -n "icmp"
```

### Check Interfaces

```bash
# Show all interfaces
ip addr show
ip link show

# Check MTU
ip link show prague0 | grep mtu
ip link show wlan0 | grep mtu

# Check WiFi hotspot
nmcli device status
nmcli connection show hotspot
```

### Test Connectivity

```bash
# From router
ping -c 3 -I prague0 1.1.1.1
ping -c 3 -I tailscale0 1.1.1.1

# From WiFi client (via adb)
adb shell 'ping -c 3 1.1.1.1'
adb shell 'curl -v http://example.com'

# Check Android connectivity check
adb shell 'curl http://connectivitycheck.gstatic.com/generate_204'
```

### Check Services

```bash
# NetworkManager
sudo systemctl status NetworkManager
nmcli general status

# nftables
sudo systemctl status nftables

# Tailscale
sudo systemctl status tailscaled
tailscale status

# dnsmasq (for hotspot)
ps aux | grep dnsmasq
```

---

## Common Issues & Fixes

### 1. WiFi Client Shows "Limited Connectivity"

**Symptoms:** Android shows "!" on WiFi icon, says limited/no internet.

**Root Causes:**
- NAT not working (source IP not translated)
- MSS clamping missing (large packets dropped)
- Conntrack entries stale

**Diagnosis:**
```bash
# Check if NAT is working
sudo tcpdump -i prague0 -n "icmp" -c 5
# Should see 10.14.0.2, NOT 192.168.54.x

# Check MSS clamping counters
sudo nft list chain inet mangle forward | grep MSS

# Check NAT counters
sudo nft list chain ip nat POSTROUTING | grep prague0
```

**Fix:**
```bash
# Flush conntrack
sudo conntrack -D -s 192.168.54.119

# Verify NAT rule exists
sudo nft list table ip nat

# Test again
adb shell 'curl http://example.com'
```

### 2. WireGuard Not Connecting

**Symptoms:** `wg show prague0` shows no handshake or old handshake timestamp.

**Root Causes:**
- Endpoint changed (DNS resolution)
- WireGuard handshake packets not routing via eth0
- Firewall blocking UDP 51820

**Diagnosis:**
```bash
# Check endpoint
sudo wg show prague0 endpoints

# Check handshake time
sudo wg show prague0 latest-handshakes
# Should be < 2 minutes ago

# Check if packets going out eth0
sudo tcpdump -i eth0 -n "udp port 51820" -c 5
```

**Fix:**
```bash
# Restart WireGuard
sudo wg-quick down prague0
sudo wg-quick up prague0

# Force endpoint refresh
# (automatically happens on restart due to DNS resolution)
```

### 3. Pings Work But HTTP/HTTPS Fails

**Symptom:** `ping 1.1.1.1` works, but `curl http://example.com` times out.

**Root Cause:** MTU / MSS issue (large packets dropped, ICMP is small).

**Diagnosis:**
```bash
# Check MTU
ip link show prague0 | grep mtu
# Should be 1380

# Check MSS clamping rules
sudo nft list chain inet mangle forward

# Try small HTTP request
curl -v http://example.com
# Hangs after "Connected..."
```

**Fix:**
```bash
# Ensure MSS clamping is active
sudo nft list chain inet mangle forward | grep maxseg
# Should show: tcp option maxseg size set 1340

# If missing, reload nftables
sudo nft -f /etc/nftables.conf

# Flush conntrack (stale TCP connections)
sudo conntrack -F
```

### 4. Hotspot Not Starting

**Symptom:** `nmcli device status` shows wlan0 disconnected.

**Root Cause:** dnsmasq configuration error.

**Diagnosis:**
```bash
# Check NetworkManager logs
sudo journalctl -u NetworkManager --since "5 minutes ago" | grep -i dnsmasq

# Common error: "bad option at line X"
```

**Fix:**
```bash
# Check dnsmasq config
cat /etc/NetworkManager/dnsmasq-shared.d/split.conf

# Remove problematic lines (e.g., filter-aaaa)
sudo vi /etc/NetworkManager/dnsmasq-shared.d/split.conf

# Restart hotspot
nmcli connection down hotspot
nmcli connection up hotspot
```

### 5. Traffic Not Going Through prague0

**Symptom:** Client traffic goes via tailscale0 instead of prague0.

**Root Cause:** Policy routing rule missing or wrong priority.

**Diagnosis:**
```bash
# Check policy rules
ip rule show | grep 192.168.54

# Should show:
# 5260:	from 192.168.54.0/24 lookup prague

# Test route lookup
ip route get 1.1.1.1 from 192.168.54.119
# Should show: ... dev prague0 table prague ...
```

**Fix:**
```bash
# Add missing rule
sudo ip rule add from 192.168.54.0/24 table prague priority 5260

# Verify prague table has route
ip route show table prague
# Should show: default dev prague0 proto prague-wg ...

# If route missing:
sudo ip route add default dev prague0 proto prague-wg metric 600 table prague
```

---

## Configuration File Locations

### Critical Files

| File | Purpose | Backup Priority |
|------|---------|----------------|
| `/etc/nftables.conf` | Firewall, NAT, MSS clamping | **CRITICAL** |
| `/etc/wireguard/prague0.conf` | WireGuard tunnel config | **CRITICAL** |
| `/etc/iproute2/rt_protos` | Custom proto definitions | High |
| `/etc/NetworkManager/system-connections/hotspot.nmconnection` | WiFi hotspot config | High |
| `/etc/NetworkManager/dnsmasq-shared.d/split.conf` | DNS split configuration | High |
| `/etc/rsnapshot.conf` | Backup configuration | Medium |
| `/etc/sysctl.conf` or `/etc/sysctl.d/*.conf` | IPv6 disable, forwarding | High |

### Backup Files Created

| File | Purpose |
|------|---------|
| `/etc/nftables.conf.backup` | Original nftables config |
| `/etc/wireguard/prague0.conf.backup` | Original WireGuard config |
| `/etc/rsnapshot.conf.orig` | Original rsnapshot config |

---

## Device: sweet (Mobile Testing Device)

**Model:** Android 15 smartphone
**Primary Connection:** asusrouter WiFi (192.168.10.x/24)
**Purpose:** Mobile troubleshooting and network testing via ADB

**Debug Access:** USB-C cable to laptop
**ADB Shell:** `adb shell` (for remote testing)

**Usage:**
- **Primary location:** Connected to asusrouter LAN
- **Mobile device:** Can connect to blackbox, asusrouter, or dyckymost networks
- **Testing tool:** Used for network troubleshooting via adb shell
- **Temporary:** May be temporarily connected to dyckymost wlan0 (192.168.54.x) for testing

**Test Commands:**
```bash
# From laptop via USB
adb shell 'ping -c 3 1.1.1.1'
adb shell 'curl http://example.com'
adb shell 'curl http://connectivitycheck.gstatic.com/generate_204'
adb shell 'nslookup google.com'

# Check which network sweet is connected to
adb shell 'ip addr show wlan0'
adb shell 'ip route show'
```

**Example Traffic Path (when on dyckymost wlan0):**
```
sweet (192.168.54.119)
  ↓ WiFi: 🇨🇿𝔪𝔬𝔰𝔱🏰
dyckymost wlan0 (192.168.54.1)
  ↓ NAT: 192.168.54.119 → 10.14.0.2
  ↓ MSS clamp: 1340 bytes
prague0 (WireGuard)
  ↓ Encryption
eth0 (192.168.1.38)
  ↓
blackbox → Internet 🇨🇿
```

---

## Device: asusrouter (Backup/Failover Router)

**Hardware:** ASUS router (ramips/mt7621 - MIPS processor)
**OS:** OpenWRT 24.10.2 (r28739-d9340319c6)
**Access:** `ssh root@192.168.10.1`

**Network Interfaces:**

| Interface   | IP Address        | Description                          |
|-------------|-------------------|--------------------------------------|
| br-lan      | 192.168.10.1/24   | LAN bridge (WiFi + LAN ports)       |
| wan         | 192.168.68.158/24 | Uplink to dyckymost eth1            |
| surfshark0  | 10.14.0.2/16      | WireGuard to Surfshark CZ-Prague    |
| phy0-ap0    | (bridge)          | 2.4GHz WiFi AP                      |
| phy1-ap0    | (bridge)          | 5GHz WiFi AP                        |

**Routing Configuration:**

```
Default via 192.168.68.1 dev wan metric 1         ← PRIMARY (dyckymost)
Default dev surfshark0 metric 2                   ← BACKUP (WireGuard)
Default dev surfshark0 metric 900                 ← BACKUP (WireGuard)
```

**Traffic Path (Normal):**
```
asusrouter LAN clients
  ↓ br-lan (192.168.10.1)
wan (192.168.68.158)
  ↓
dyckymost eth1 (192.168.68.1)
  ↓
tailscale0 → Exit Node (100.112.56.95) → Internet
```

**Traffic Path (Failover):**
```
asusrouter LAN clients
  ↓ br-lan (192.168.10.1)
surfshark0 (10.14.0.2)
  ↓ WireGuard tunnel
wan → dyckymost eth0 → Internet 🇨🇿
```

**WireGuard Configuration:**
- **Interface:** surfshark0
- **Tunnel IP:** 10.14.0.2/16 (same as dyckymost prague0)
- **Endpoint:** cz-prg.prod.surfshark.com:51820 (185.242.6.67)
- **MTU:** 1420 bytes
- **Handshake:** Active and healthy

**Firewall (nftables/fw4):**
- **Zones:** lan (accept all), wan (reject input/forward)
- **NAT:** Masquerading on wan and surfshark0
- **MSS Clamping:** Automatic MTU fixing enabled
- **Open Ports:** SSH (22), HTTP (80)

**DNS Configuration:**
- **Local Domain:** asusnet
- **dnsmasq:** Provides DHCP + DNS for 192.168.10.0/24
- **Upstream DNS:** Uses wan (dyckymost) or Surfshark DNS servers
- **Filter:** IPv6 AAAA records filtered (filter_aaaa=1)

**Active LAN Clients:**
- Hostimil (192.168.10.243)
- Mac (192.168.10.236)
- Bolemir (192.168.10.129)
- Zenfone-10 (192.168.10.131)
- 2 unnamed devices (.247, .206)

**Custom Script:** mwan (multi-WAN failover based on ping statistics) - future enhancement

**Notes:**
- Uses same Surfshark account as dyckymost (same tunnel IP 10.14.0.2)
- Automatically fails over to local WireGuard when dyckymost becomes unavailable
- Performance limited by MIPS CPU (80/120 Mbps vs 100/150 Mbps on dyckymost)
- IPv6 disabled system-wide (sysctl)

---

## Quick Reference

### Restart Everything

```bash
# Restart WireGuard
sudo wg-quick down prague0 && sudo wg-quick up prague0

# Restart hotspot
nmcli connection down hotspot && nmcli connection up hotspot

# Restart Tailscale
sudo systemctl restart tailscaled

# Reload firewall
sudo nft -f /etc/nftables.conf

# Reboot router
sudo reboot
```

### Check Routing Decision

```bash
# What route will be used for packet from WiFi client to 1.1.1.1?
ip route get 1.1.1.1 from 192.168.54.119

# Expected output:
# 1.1.1.1 dev prague0 table prague src 10.14.0.2
```

### Check NAT is Working

```bash
# Start ping from sweet
adb shell 'ping 1.1.1.1' &

# Capture on prague0 - should see 10.14.0.2 as source
sudo tcpdump -i prague0 -n icmp -c 5

# Should see:
# IP 10.14.0.2 > 1.1.1.1: ICMP echo request
# IP 1.1.1.1 > 10.14.0.2: ICMP echo reply
```

### Monitor Traffic

```bash
# Real-time interface statistics
watch -n 1 'ip -s link show'

# Monitor nftables counters
watch -n 1 'sudo nft list chain inet filter forward'

# Monitor connections
watch -n 1 'sudo conntrack -L | grep 192.168.54.119'
```

---

## Change Log

### 2025-10-26: Major Routing Fix & Cleanup

**Changes:**
1. ✅ Disabled IPv6 system-wide
2. ✅ Fixed WireGuard handshake (restarted with wg-quick)
3. ✅ Added NAT masquerading for prague0
4. ✅ Implemented MSS clamping (1340 bytes for MTU 1380)
5. ✅ Fixed nftables forward rules (allow wlan0→prague0)
6. ✅ Consolidated nftables config to `/etc/nftables.conf`
7. ✅ Simplified WireGuard PostUp/PostDown scripts
8. ✅ Added custom route protocol `prague-wg` (ID 17)
9. ✅ Configured rsnapshot automated backups
10. ✅ Fixed dnsmasq hotspot issue (removed `filter-aaaa`)

**Verified Working:**
- ✅ ICMP (ping)
- ✅ DNS resolution
- ✅ HTTP/HTTPS
- ✅ Android connectivity check
- ✅ WiFi hotspot
- ✅ Policy routing (wlan0 → prague0, others → tailscale0)

**Issues Resolved:**
- WiFi client "limited connectivity" → Fixed NAT + MSS clamping
- HTTP timeouts → Fixed MSS clamping
- WireGuard no reply → Restarted tunnel (endpoint changed)
- Hotspot not broadcasting → Fixed dnsmasq config
- Traffic not routing via prague0 → Fixed forward chain rules

### 2025-10-29: DNS Architecture Redesign - "Chain of Irresponsibility"

**Problem Identified:**
- dyckymost could not resolve its own hostname `dyckymost.raspinet`
- NetworkManager's dnsmasq instances run with `--no-hosts` flag, ignoring `/etc/hosts`

**Root Cause Analysis:**
- NetworkManager runs 3 separate dnsmasq instances (127.0.0.1, 192.168.54.1, 192.168.68.1)
- Each instance has isolated state (no shared DHCP lease information)
- Both wlan0 and eth1 use the same `--conf-dir=/etc/NetworkManager/dnsmasq-shared.d`
- Cannot configure different authoritative zones per interface due to shared config

**Architectural Decisions:**

1. **"Chain of Irresponsibility" Pattern Implemented:**
   - 127.0.0.1 (master) → holds static hosts, forwards to public DNS
   - 192.168.54.1 & 192.168.68.1 (edge) → serve DHCP leases, forward everything else to 127.0.0.1
   - Centralized caching at master level
   - Single source of truth for static infrastructure hosts

2. **Cross-Interface DNS Forwarding Abandoned:**
   - Attempted: Configure 127.0.0.1 to forward `.raspinet` to both edge instances
   - Failed due to: dnsmasq forwarding semantics (authoritative NXDOMAIN stops forwarding chain)
   - Accepted limitation: localhost cannot resolve DHCP clients from wlan0/eth1

3. **Public DNS Choice (8.8.8.8, 1.1.1.1):**
   - Evaluated: Surfshark Prague DNS (closer, ~5ms) vs anycast public DNS (~25ms)
   - Decided: Public DNS for multi-WAN compatibility
   - Reasoning: tailscale0 failover makes Surfshark Prague DNS suboptimal when not using prague0
   - Trade-off: ~20ms extra latency for architectural simplicity

**Changes:**
1. ✅ Added `host-record` entries for dyckymost to `/etc/NetworkManager/dnsmasq.d/split.conf`
2. ✅ Configured edge instances to forward to 127.0.0.1 only (no direct public DNS access)
3. ✅ Documented NetworkManager architectural constraints
4. ✅ Explained DNS forwarding semantics and why cross-interface resolution is impossible

**Verified Working:**
- ✅ Static hosts resolve from all dnsmasq instances
- ✅ DHCP clients resolve their own hostnames
- ✅ WiFi clients can query internet DNS via chain (wlan0 → 127.0.0.1 → 8.8.8.8)
- ✅ Centralized DNS caching at master level

**Configuration Files:**
- `/etc/NetworkManager/dnsmasq.d/split.conf` - master resolver config
- `/etc/NetworkManager/dnsmasq-shared.d/split.conf` - edge instances config

**Accepted Limitations:**
- 127.0.0.1 cannot resolve DHCP clients from wlan0/eth1 (by design)
- Single point of failure: 127.0.0.1 crash breaks internet DNS for edge instances
- ~1-5ms extra latency per query due to forwarding hop

### 2025-10-30: Critical Conntrack Bug Fix - Every-Second-Packet Drop Issue

**Problem Identified:**
- eth1 → eth0 WireGuard traffic experiencing alternating packet loss (every odd packet works, every even packet fails)
- Conntrack entries staying in [UNREPLIED] state, getting [DESTROY]ed after 2-3 seconds
- Pattern: NEW → UPDATE → DESTROY → NEW → UPDATE → DESTROY (continuous cycle)

**Root Cause Analysis:**

1. **Double NAT Problem:**
   - Two NAT rules applied to same traffic: mark-based masquerade (handle 9) AND NetworkManager masquerade (nm-shared-eth1)
   - Only 6 packets matched mark-based rule, 101 packets fell through to NetworkManager NAT
   - Inconsistent NAT handling created conntrack confusion

2. **NAT Priority Conflict:**
   - PREROUTING mark rule in NAT table at priority dstnat
   - Conntrack NAT un-NAT also happens at priority dstnat
   - Marking and conntrack processing **interfered with each other**
   - Reply packets couldn't be properly un-NAT'd back to original source

3. **Why Alternating Packets?**
   - **Packet 1 (ODD):** Creates [NEW] conntrack entry → forwarded (NEW entries always allowed)
   - **Packet 2 (EVEN):** Uses existing [UNREPLIED] entry → conntrack treats as potentially invalid → dropped or misrouted
   - **Packet 3 (ODD):** Old entry [DESTROY]ed, creates NEW entry again → works
   - Deterministic pattern due to regular packet intervals (< UDP unreplied timeout)

**Changes Made:**

1. ✅ **Removed problematic NAT rules:**
   - Deleted PREROUTING mark rule (handle 3) from NAT table
   - Deleted POSTROUTING mark-based masquerade (handle 9) from NAT table
   - Left only NetworkManager's masquerade (single NAT path)

2. ✅ **Added mangle PREROUTING marking:**
   ```nft
   chain prerouting {
       type filter hook prerouting priority mangle;
       iifname "eth1" udp dport 51820 meta mark set 0x100000
   }
   ```
   - Marks at **mangle priority (-150)** - runs **before** conntrack NAT (-100)
   - No interference with conntrack state tracking
   - Only marks **outbound** packets (dport 51820), not replies (sport 51820)

3. ✅ **Fixed WireGuard PostUp:**
   - **Removed:** `ip rule add from all table prague priority 5300`
   - This rule was routing ALL traffic (including eth1→eth0 forwarded traffic) through prague0
   - Caused original routing conflicts before conntrack issue was discovered

4. ✅ **Added FwMark to WireGuard config:**
   - `FwMark = 0x100000` in `/etc/wireguard/prague0.conf`
   - Marks WireGuard's own protocol packets at socket creation
   - Ensures correct source IP selection (192.168.1.38 instead of Tailscale IP)

5. ✅ **Added local traffic failover:**
   - NetworkManager dispatcher script: `/etc/NetworkManager/dispatcher.d/98-failover-routing`
   - Automatically adds rules for dyckymost's own traffic:
     - Priority 5270: from 192.168.1.38 lookup tailscale (PRIMARY)
     - Priority 5280: from 192.168.1.38 lookup prague (FAILOVER)
     - Priority 5290: from 192.168.1.38 unreachable (KILL SWITCH)

**Verified Working:**
- ✅ Conntrack entries now reach [ASSURED] state
- ✅ No more [DESTROY] cycles
- ✅ All packets passing through consistently
- ✅ Replies properly un-NAT'd to eth1 clients
- ✅ Traffic from eth1 → eth0 works via NetworkManager NAT

**Key Learnings:**
1. **Mangle priority matters:** Marking must happen **before** conntrack NAT processing
2. **Single NAT path:** Avoid multiple masquerade rules for same traffic
3. **Conntrack UDP behavior:** [UNREPLIED] entries create deterministic failure patterns
4. **FwMark placement:** Socket creation (WireGuard config) vs packet marking (nftables) have different effects on source IP selection
5. **Policy routing conflicts:** "from all" rules can inadvertently catch forwarded traffic

**Configuration Files Updated:**
- `/etc/wireguard/prague0.conf` - Added FwMark, removed priority 5300 rule
- `/etc/nftables.conf` - Added mangle prerouting chain, removed problematic NAT rules
- `/etc/NetworkManager/dispatcher.d/98-failover-routing` - Added local traffic failover
- Documentation updated to reflect actual working configuration

---

## Future Enhancements

**Potential improvements:**

1. **Monitor WireGuard Health:**
   - Script to check handshake age
   - Auto-restart if handshake stale (>3 minutes)

2. **Failover to Tailscale:**
   - If prague0 fails, route WiFi clients via tailscale0
   - Use `fping` or similar for health checks

3. **Re-enable asusrouter:**
   - Connect dyckymost eth1 → asusrouter wan
   - Use asusrouter's mwan script for multi-WAN

4. **IPv6 Re-enablement:**
   - If needed in future, add IPv6 policy routing
   - Configure IPv6 NAT/masquerading for prague0

5. **Hotspot Improvements:**
   - Separate SSID for guests (untrusted)
   - VLAN separation

6. **Monitoring Dashboard:**
   - Grafana + Prometheus
   - Track bandwidth, connection counts, WireGuard stats

---

## Support & Documentation

**Created by:** Claude (Anthropic)
**Session Date:** 2025-10-26
**Network Owner:** slavibor

**For future help, provide:**
- This documentation file
- Output of `ip route show table all`
- Output of `sudo nft list ruleset`
- Output of `ip rule show`
- Output of `sudo wg show`

**Useful Resources:**
- WireGuard: https://www.wireguard.com/
- nftables: https://wiki.nftables.org/
- iproute2: https://wiki.linuxfoundation.org/networking/iproute2
- Tailscale: https://tailscale.com/kb/

---

*End of Documentation*
