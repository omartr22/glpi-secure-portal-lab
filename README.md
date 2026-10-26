# Aegis Corp – Secure GLPI Portal (Lab)

> 🇫🇷 Version française : [README.fr.md](README.fr.md)

A lab project that rebuilds a **fully secured ITSM portal (GLPI)** the way it would be done in a demanding enterprise environment: network segmentation, TLS everywhere, internal PKI, Active Directory authentication over LDAPS, and a restricted mail relay.

**Status:** 🚧 In progress – Phase 2 (Active Directory and DNS)

> This is a personal lab project built on a fictional company (Aegis Corp). It is not production experience.

## Architecture

```
 Users (LAN 10.10.10.0/24)
          │ HTTPS 443
          ▼
 ┌───────────────────────┐
 │ gw-haproxy            │  HAProxy (TLS termination) + nftables + Postfix relay
 │ LAN .5 │ DMZ .5       │
 └───────────────────────┘
          │ HTTPS 443 (re-encrypted, cert signed by Aegis Root CA)
          ▼
 ┌───────────────────────┐        LDAPS 636 (TLS 1.2+)       ┌──────────────────┐
 │ glpi01  (DMZ .20)     │ ────────────────────────────────► │ dc01 (LAN .10)   │
 │ Apache/PHP/MariaDB    │                                    │ AD DS, DNS, AD CS│
 └───────────────────────┘                                    └──────────────────┘
```

Full details: [docs/00-architecture.md](docs/00-architecture.md)

## Stack

Windows Server 2022 (AD DS, DNS, AD CS) · Ubuntu Server 24.04 · HAProxy · nftables · GLPI · Apache · MariaDB · Postfix · VMware Workstation

## Roadmap

| Phase | Topic | Status |
|---|---|---|
| 0 | Design, IP plan, repo | ✅ |
| 1 | VMs and segmented network, firewall baseline | ✅ |
| 2 | Active Directory and DNS | 🚧 |
| 3 | Internal PKI (AD CS) and root cert deployment via GPO | ⬜ |
| 4 | GLPI installation | ⬜ |
| 5 | HAProxy, TLS termination, re-encryption | ⬜ |
| 6 | LDAPS authentication, AD group → GLPI profile rules | ⬜ |
| 7 | Postfix SMTP relay | ⬜ |
| 8 | Branding, custom fields, templates | ⬜ |
| 9 | Hardening, backups, test plan | ⬜ |
| 10 | Bonus: Entra Connect and SAML/OIDC SSO | ⬜ |
| 11 | Final documentation and write-up | ⬜ |

## Documentation

- [Architecture and IP plan](docs/00-architecture.md)
- [Phase 1 – VMs and network](docs/01-phase1-vms-network.md)
- [Phase 2 – Active Directory and DNS](docs/02-phase2-ad-dns.md)

## Skills demonstrated

Network segmentation (LAN/DMZ) · Linux firewalling · Reverse proxy and TLS · PKI · Active Directory · GPO · LDAPS · ITSM · SMTP relay · Technical documentation
