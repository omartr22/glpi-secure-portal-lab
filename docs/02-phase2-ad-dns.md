# Phase 2 – Active Directory and DNS

**Goal:** a working domain `ad.aegis-corp.lab` on `dc01`, with DNS records for the lab hosts, an OU structure, GLPI security groups, test users and a least-privilege LDAP bind account.

Only `dc01` is needed for the installation. `gw-haproxy` is needed only for the DNS test from `glpi01` and for the DNS forwarder.

## 1. Preparation

Take a snapshot `phase1-ok` of `dc01` first, then in PowerShell (administrator):

```powershell
Set-TimeZone -Id "W. Central Africa Standard Time"     # Tunisia, UTC+1
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
```

Remote Desktop lets you work from the Windows host (`mstsc` → `10.10.10.10`) with a working clipboard.

## 2. Install AD DS and DNS

```powershell
Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools
```

## 3. Promote `dc01` (new forest)

```powershell
Install-ADDSForest `
  -DomainName "ad.aegis-corp.lab" `
  -DomainNetbiosName "AEGIS" `
  -ForestMode WinThreshold -DomainMode WinThreshold `
  -InstallDns `
  -SafeModeAdministratorPassword (Read-Host -AsSecureString "DSRM password") `
  -Force
```

`WinThreshold` is the Windows Server 2016 functional level, the highest available on Server 2022. The server reboots by itself. Warnings about DNS delegation and cryptography are expected in a new lab forest.

After the reboot, sign in as `AEGIS\Administrator`.

## 4. DNS configuration

```powershell
# The DC resolves through itself
Set-DnsClientServerAddress -InterfaceAlias "Ethernet1" -ServerAddresses 127.0.0.1

# Forwarder for external names (needs gw-haproxy powered on)
Add-DnsServerForwarder -IPAddress 1.1.1.1

# Reverse zones for both subnets
Add-DnsServerPrimaryZone -NetworkId "10.10.10.0/24" -ReplicationScope Domain
Add-DnsServerPrimaryZone -NetworkId "10.10.20.0/24" -ReplicationScope Domain

# Records for the lab hosts
$zone = "ad.aegis-corp.lab"
Add-DnsServerResourceRecordA -ZoneName $zone -Name "gw-haproxy" -IPv4Address 10.10.10.5  -CreatePtr
Add-DnsServerResourceRecordA -ZoneName $zone -Name "glpi01"     -IPv4Address 10.10.20.20 -CreatePtr
Add-DnsServerResourceRecordA -ZoneName $zone -Name "support"    -IPv4Address 10.10.10.5     # portal FQDN -> HAProxy
```

`support.ad.aegis-corp.lab` points to the HAProxy frontend: users never resolve or reach the GLPI server directly.

## 5. OUs, groups, users

Run `scripts/02-create-ad-objects.ps1` on `dc01` (paste it into an elevated PowerShell). It asks for passwords at runtime, so no secret is stored in the repository.

| Object | Name | Purpose |
|---|---|---|
| OU | `Aegis` → `Users`, `Groups`, `Computers`, `Service Accounts` | Clean structure, protected from accidental deletion |
| Group | `GLPI-Admins` | → Super-Admin profile (Phase 6) |
| Group | `GLPI-Support` | → Technician profile |
| Group | `GLPI-Hotline` | → Hotliner profile |
| Group | `GLPI-Users` | → Self-Service profile |
| User | `agharbi`, `sbenyoussef`, `ymejri`, `rhamdi` | One test user per group |
| Service account | `svc-glpi-ldap` | LDAP bind account for GLPI, plain domain user (read only) |

## 6. Validation

On `dc01`:

```powershell
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode
dcdiag /q                                                    # no output = all tests passed
nslookup dc01.ad.aegis-corp.lab 127.0.0.1
nslookup -type=SRV _ldap._tcp.dc._msdcs.ad.aegis-corp.lab 127.0.0.1
nslookup support.ad.aegis-corp.lab 127.0.0.1
Get-ADGroupMember GLPI-Support
```

From `glpi01` (with `gw-haproxy` and `dc01` running), point DNS to the DC in `/etc/netplan/50-cloud-init.yaml`:

```yaml
      nameservers:
        addresses: [10.10.10.10]
        search: [ad.aegis-corp.lab]
```

```bash
sudo netplan apply
resolvectl query dc01.ad.aegis-corp.lab
resolvectl query support.ad.aegis-corp.lab
```

| Test | Expected |
|---|---|
| `dcdiag /q` on dc01 | No output |
| SRV record `_ldap._tcp.dc._msdcs` | Returns `dc01.ad.aegis-corp.lab` |
| `support.ad.aegis-corp.lab` | `10.10.10.5` |
| glpi01 resolves `dc01.ad.aegis-corp.lab` | `10.10.10.10` (DNS flow allowed by the gateway) |
| `nc -zv 10.10.10.10 636` from glpi01 | Refused for now. LDAPS needs a certificate, which comes in Phase 3 |

Screenshots to keep in `docs/img/`: Active Directory Users and Computers (OU tree), DNS Manager (zones and records), `dcdiag` and `nslookup` results.

## 7. Snapshot and commit

Snapshot `phase2-ok` on `dc01` (and on `glpi01` after the DNS change), then commit this file, the script and the screenshots.
