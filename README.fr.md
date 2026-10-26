# Aegis Corp – Portail GLPI sécurisé (Lab)

> 🇬🇧 English version: [README.md](README.md)

Projet de laboratoire qui reconstruit un **portail ITSM (GLPI) entièrement sécurisé** comme dans un environnement d'entreprise exigeant : segmentation réseau, TLS partout, PKI interne, authentification Active Directory via LDAPS et relais de messagerie restreint.

**Statut :** 🚧 En cours – Phase 2 (Active Directory et DNS)

> Projet personnel de laboratoire sur une entreprise fictive (Aegis Corp). Il ne s'agit pas d'une expérience en production.

## Architecture

```
 Utilisateurs (LAN 10.10.10.0/24)
          │ HTTPS 443
          ▼
 ┌───────────────────────┐
 │ gw-haproxy            │  HAProxy (terminaison TLS) + nftables + relais Postfix
 │ LAN .5 │ DMZ .5       │
 └───────────────────────┘
          │ HTTPS 443 (rechiffré, certificat signé par Aegis Root CA)
          ▼
 ┌───────────────────────┐        LDAPS 636 (TLS 1.2+)       ┌──────────────────┐
 │ glpi01  (DMZ .20)     │ ────────────────────────────────► │ dc01 (LAN .10)   │
 │ Apache/PHP/MariaDB    │                                    │ AD DS, DNS, AD CS│
 └───────────────────────┘                                    └──────────────────┘
```

Détails : [docs/00-architecture.md](docs/00-architecture.md)

## Technologies

Windows Server 2022 (AD DS, DNS, AD CS) · Ubuntu Server 24.04 · HAProxy · nftables · GLPI · Apache · MariaDB · Postfix · VMware Workstation

## Feuille de route

| Phase | Sujet | Statut |
|---|---|---|
| 0 | Conception, plan d'adressage, dépôt | ✅ |
| 1 | VM, réseau segmenté, pare-feu de base | ✅ |
| 2 | Active Directory et DNS | 🚧 |
| 3 | PKI interne (AD CS) et déploiement du certificat racine par GPO | ⬜ |
| 4 | Installation de GLPI | ⬜ |
| 5 | HAProxy, terminaison TLS, rechiffrement | ⬜ |
| 6 | Authentification LDAPS, règles groupes AD → profils GLPI | ⬜ |
| 7 | Relais SMTP Postfix | ⬜ |
| 8 | Personnalisation : thème, champs, modèles | ⬜ |
| 9 | Durcissement, sauvegardes, plan de tests | ⬜ |
| 10 | Bonus : Entra Connect et SSO SAML/OIDC | ⬜ |
| 11 | Documentation finale | ⬜ |

## Documentation

- [Architecture et plan d'adressage](docs/00-architecture.md)
- [Phase 1 – VM et réseau](docs/01-phase1-vms-network.md)
- [Phase 2 – Active Directory et DNS](docs/02-phase2-ad-dns.md)

## Compétences démontrées

Segmentation réseau (LAN/DMZ) · Pare-feu Linux · Reverse proxy et TLS · PKI · Active Directory · GPO · LDAPS · ITSM · Relais SMTP · Documentation technique
