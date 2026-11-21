# Module firewall — M2 (NVA firewall)

Responsable : **M2 (NVA firewall)**

Tu travailles uniquement dans `modules/firewall/`. Ne modifie pas `environments/dev` ni les autres modules.

## Contrat (ne pas casser)
- Variables : voir `variables.tf` (tu peux en AJOUTER avec une valeur par défaut, pas en renommer/supprimer).
- Outputs : voir `outputs.tf` (les noms sont utilisés par l'intégration). Remplace les placeholders par les vraies ressources.

## Démarrer
```bash
cd modules/firewall
terraform init -backend=false
cd ../.. && ./check.sh modules/firewall
```
Aucun compte Azure n'est nécessaire : les tests utilisent `mock_provider`.

## Ce que crée le module

| Ressource | Nom | Rôle |
|---|---|---|
| IP publique Standard statique | `pip-<prefix>-nva` | Entrée Internet (DNAT) + sortie SNAT du VNet |
| NIC primaire (eth0, *untrust*) | `nic-<prefix>-nva` | IP `10.10.0.4`, IP forwarding, porte l'IP publique — **next hop des UDR** |
| NIC secondaire (eth1, *trust*) | `nic-<prefix>-nva-trust` | IP forwarding, route `10.10.0.0/16` vers les subnets internes (`enable_trust_nic = false` pour la désactiver) |
| VM Ubuntu 22.04 | `vm-<prefix>-nva` | nftables, `ip_forward=1`, SSH par clé uniquement, boot diagnostics |

Le script `scripts/install-firewall.sh` (custom_data) active l'IP forwarding, installe nftables,
génère `/etc/nftables.conf` à partir de `scripts/nftables.conf` et installe l'outil `nft-safe-apply`.

## Matrice de flux (nftables, policy **drop** sur input et forward)

| Source | Destination | Ports | Remarque |
|---|---|---|---|
| Internet | IP publique NVA → **DNAT** vm-web `10.10.1.4` | tcp 80, 443 | `dnat_tcp_ports` |
| vm-web `10.10.1.4` | vm-app `10.10.2.4` | tcp 8080 | `app_tcp_ports` |
| mgmt `10.10.3.0/24` | tout le VNet + la NVA | tcp 22, icmp | administration |
| vm-monitor `10.10.4.4` | tout le VNet + la NVA | tcp 9100 | `monitoring_scrape_tcp_ports` |
| tout le VNet | vm-monitor | tcp 3100 | `monitoring_ingest_tcp_ports` (Loki) |
| tout le VNet | Internet (SNAT) | tcp 80/443, udp 53/123 | mises à jour |
| DMZ | LAN / mgmt / monitoring (autre que ci-dessus) | — | **drop + log** `nft-dmz-pivot:` |

Logs des refus : `journalctl -k | grep nft-`.

## Anti-lockout
1. **1re règle** de la chaîne `input` : SSH depuis le subnet mgmt toujours accepté (vérifié par un test).
2. Au boot, les règles ne sont appliquées **que si** `nft -c` valide la syntaxe ; sinon rien ne change et l'erreur est dans `/var/log/nva-install.log`.
3. Pour modifier les règles à la main : `sudo nft-safe-apply /tmp/regles.conf` → rollback automatique après 60 s (planifié par systemd, donc même si la session SSH coupe) sauf si `sudo nft-safe-apply --confirm`.
4. Dernier recours : Serial Console Azure (boot diagnostics activé).

## Ce dont les autres membres ont besoin
- **M3 (routing)** : UDR `0.0.0.0/0` + routes inter-subnets → next hop `VirtualAppliance` = `module.firewall.nva_private_ip`.
  Le NSG du subnet firewall doit autoriser **tcp 80/443 depuis Internet** (l'IP publique Standard est fermée par défaut) et le trafic du VNet.
- **M4 (dmz)** : le site est publié via `nva_public_ip` (ports 80/443).
- **M5 (lan)** : l'app doit écouter sur `app_tcp_ports` (8080 par défaut), sinon ajuster la variable.
- **M6 (monitoring)** : node_exporter 9100 et Loki 3100 par défaut ; output `nftables_ruleset` disponible pour des tests.

## Fins de ligne
`.gitattributes` force LF sur `*.sh` / `*.conf`, et `main.tf` retire les `\r` du custom_data :
un script en CRLF (`#!/bin/bash\r`) ne s'exécute pas sous cloud-init.
