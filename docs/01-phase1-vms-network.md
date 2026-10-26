# Phase 1 – VMs and segmented network

**Goal:** three VMs on the right networks, a working gateway with a default-deny firewall, and verified connectivity.

## 1. VMware networks

In *Edit → Virtual Network Editor* (run as administrator):

| Network | Type | Subnet | DHCP | Host adapter |
|---|---|---|---|---|
| VMnet3 | Host-only | 10.10.10.0/24 | Off | Connected |
| VMnet4 | Host-only | 10.10.20.0/24 | Off | Optional |
| VMnet8 | NAT | default | n/a | default |

## 2. Create the VMs

> **Isolation rule:** only `gw-haproxy` gets a NAT adapter. A NAT adapter on `dc01` or `glpi01` creates a path around the gateway and its firewall, which silently breaks segmentation (see section 8).

Use thin-provisioned disks (do not pre-allocate), no 3D acceleration, and remove the sound card and printer to save RAM.

| VM | RAM | vCPU | Disk | NIC order |
|---|---|---|---|---|
| `dc01` | 2048 MB | 2 | 40 GB | 1 × VMnet3 |
| `gw-haproxy` | 768 MB | 1 | 10 GB | 1 × VMnet8, 2 × VMnet3, 3 × VMnet4 |
| `glpi01` | 1536 MB | 2 | 20 GB | 1 × VMnet4 |

Install notes:
- **dc01:** Windows Server 2022 Standard Evaluation, *Desktop Experience*. Hostname `DC01`.
- **gw-haproxy and glpi01:** Ubuntu Server 24.04, *minimized* install, OpenSSH server enabled, no extra snaps.

## 3. Gateway network config (`gw-haproxy`)

Check interface names first with `ip -br a`. The examples assume `ens33` = NAT, `ens34` = LAN, `ens35` = DMZ. Adapt if yours differ (match them by MAC address in the VM settings).

`/etc/netplan/50-aegis.yaml`:

```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: true
    ens34:
      addresses: [10.10.10.5/24]
    ens35:
      addresses: [10.10.20.5/24]
```

Apply and enable routing:

```bash
sudo chmod 600 /etc/netplan/50-aegis.yaml
sudo netplan apply
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-forward.conf
sudo sysctl --system
sudo hostnamectl set-hostname gw-haproxy
```

## 4. Gateway firewall (`/etc/nftables.conf`)

```nft
#!/usr/sbin/nft -f
flush ruleset

define WAN = ens33
define LAN = ens34
define DMZ = ens35

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    ct state invalid drop
    iif lo accept
    ip protocol icmp accept
    iifname $LAN tcp dport 22 accept
    # Phase 5: iifname $LAN tcp dport 443 accept
    # Phase 7: iifname $DMZ ip saddr 10.10.20.20 tcp dport 25 accept
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
    ct state established,related accept
    # glpi01 -> dc01 : DNS, LDAPS, NTP
    iifname $DMZ oifname $LAN ip saddr 10.10.20.20 ip daddr 10.10.10.10 tcp dport { 53, 636 } accept
    iifname $DMZ oifname $LAN ip saddr 10.10.20.20 ip daddr 10.10.10.10 udp dport { 53, 123 } accept
    # TEMPORARY: internet for installs and updates (remove in Phase 9)
    iifname { $LAN, $DMZ } oifname $WAN accept
  }
}

table ip nat {
  chain postrouting {
    type nat hook postrouting priority 100;
    # TEMPORARY (remove in Phase 9)
    oifname $WAN masquerade
  }
}
```

```bash
sudo nft -c -f /etc/nftables.conf     # syntax check
sudo systemctl enable --now nftables
sudo nft -f /etc/nftables.conf
```

## 5. Addressing of the other VMs

**glpi01** (`/etc/netplan/50-aegis.yaml`):

```yaml
network:
  version: 2
  ethernets:
    ens33:
      addresses: [10.10.20.20/24]
      routes:
        - to: default
          via: 10.10.20.5
      nameservers:
        addresses: [1.1.1.1]
```

The interface name depends on the VM (`ens34` in the validated lab, check with `ip -br a`). Protect the file and stop cloud-init from overwriting it:

```bash
sudo chmod 600 /etc/netplan/50-cloud-init.yaml
echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```

Do the same on `gw-haproxy`.

(DNS will switch to `10.10.10.10` once AD DNS exists in Phase 2.)

**dc01** (Network adapter IPv4 properties): IP `10.10.10.10`, mask `255.255.255.0`, gateway `10.10.10.5`, DNS `1.1.1.1` for now (it becomes `127.0.0.1` in Phase 2).

## 6. Validation checklist

| Test | Expected |
|---|---|
| `gw-haproxy`: `ping 10.10.10.10` and `ping 10.10.20.20` | OK |
| `gw-haproxy`: `ping 1.1.1.1` | OK |
| `glpi01`: `ping 10.10.20.5` | OK |
| `glpi01`: `ping 1.1.1.1` | OK (temporary NAT) |
| `glpi01`: `ping 10.10.10.10` | Blocked (ICMP not allowed in forward, only listed ports) |
| `dc01`: `ping 10.10.10.5` | OK |
| `dc01`: `ping 10.10.20.20` | Blocked (LAN cannot reach DMZ directly) |
| `sudo nft list ruleset` | Matches the file above |

The two "Blocked" results are the proof that segmentation works. Take screenshots of them for `docs/img/`.

## 7. Validation results (2026-10-16)

| Test | Result |
|---|---|
| gw-haproxy → 10.10.10.10 / 10.10.20.20 / 1.1.1.1 | OK |
| glpi01 → 10.10.20.5 | OK, `ttl=64` (Linux gateway answers) |
| glpi01 → 1.1.1.1 | OK, first hop `10.10.20.5` (traceroute), then the NAT gateway |
| glpi01 → 10.10.10.10 | Blocked, 100% loss (timeout) |
| dc01 → 10.10.10.5 | OK, `TTL=64` |
| dc01 → 10.10.20.20 | Blocked, timeout |

Segmentation is validated: the DMZ and the LAN can only talk through the gateway, and only on the flows listed in the architecture document.

## 8. Lessons learned

**Symptom:** `glpi01 → dc01` ping succeeded and `dc01 → glpi01` answered from the Windows host (`10.10.20.1`), although the firewall should have dropped both.

**Cause:** an extra NAT adapter had been added to `dc01` and `glpi01` for SSH access. Its default route (metric 25 on Windows) won over the gateway, so traffic bypassed `gw-haproxy`. The clue was `ttl=128` in replies that should have come from a Linux gateway.

**Fix:** remove the NAT adapters from `dc01` and `glpi01`. Administration goes through the host-only adapters of the Windows host (`10.10.10.1` and `10.10.20.1`): SSH to `10.10.10.5` and `10.10.20.20`, RDP to `10.10.10.10`. Internet access for updates goes through the gateway masquerade rule.

**Takeaway:** a segmentation test is only valid if every VM has a single path out. Always check `ip route` / `route print` for a second default route.

## 9. Snapshots and commit

Take a VMware snapshot named `phase1-ok` of each VM, then commit this documentation to the repo.
