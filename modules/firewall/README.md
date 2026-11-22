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

## Travail réalisé (M2)

**Statut :** module terminé, branche `feat/firewall`. `./check.sh modules/firewall` passe :
fmt, validate, tflint (y compris `terraform_unused_declarations`), 11/11 tests, Checkov 8/8
(3 exceptions justifiées : IP forwarding ×2, IP publique sur la NIC).

### Fichiers

| Fichier | Contenu |
|---|---|
| `main.tf` | IP publique, 2 NIC (IP forwarding), VM, rendu des templates, préconditions (ports, CIDR) |
| `variables.tf` | Variables du squelette (inchangées) + variables ajoutées, toutes avec une valeur par défaut |
| `outputs.tf` | Les 4 outputs du contrat pointent vers les vraies ressources + 3 outputs ajoutés |
| `scripts/nftables.conf` | Template du ruleset (Terraform y injecte les IP et les ports) |
| `scripts/install-firewall.sh` | custom_data : sysctl, nftables, route eth1, installation de `nft-safe-apply` |
| `scripts/nft-safe-apply.sh` | Outil de modification des règles avec rollback automatique |
| `tests/firewall.tftest.hcl` | 11 tests `mock_provider` |
| `.gitattributes` | Force LF sur `*.sh` et `*.conf` |

### Outputs

| Output | Valeur | Utilisé par |
|---|---|---|
| `nva_vm_id` | ID de la VM | M1 |
| `nva_nic_id` | ID de eth0 | M1 |
| `nva_private_ip` | `10.10.0.4`, connue dès le `plan` | M3 (next hop des UDR) |
| `nva_public_ip` | IP publique | M4, M1 (accès au site, F06) |
| `nva_trust_nic_id` *(ajouté)* | ID de eth1, `null` si désactivée | — |
| `nva_trust_private_ip` *(ajouté)* | IP de eth1 | — |
| `nftables_ruleset` *(ajouté)* | Ruleset rendu | tests, revue, M6 |

### Variables ajoutées (toutes optionnelles)

- **Topologie** : `enable_trust_nic`, `trust_subnet_id`, `trust_subnet_cidr`, `trust_private_ip_address`, `allow_extension_operations`.
- **Plan d'adressage** (valeurs par défaut = plan figé) : `vnet_cidr`, `firewall_subnet_cidr`, `dmz_subnet_cidr`,
  `lan_subnet_cidr`, `mgmt_subnet_cidr`, `monitoring_subnet_cidr`, `web_private_ip`, `app_private_ip`,
  `monitoring_private_ip`, `bastion_private_ip`.
- **Flux** : `dnat_tcp_ports`, `app_tcp_ports`, `monitoring_scrape_tcp_ports`, `monitoring_ingest_tcp_ports`,
  `monitoring_ui_tcp_ports`, `egress_tcp_ports`, `egress_udp_ports`, `admin_source_ips`, `admin_ssh_dnat_port`.

### Choix techniques

- **2 NIC dans le même subnet firewall** : le plan d'adressage ne prévoit qu'un subnet pour la NVA.
  eth0 porte l'IP publique et la route par défaut, eth1 la route `10.10.0.0/16`. `rp_filter = 2` (mode souple)
  évite que Linux jette les paquets qui entrent par une carte et sortent par l'autre.
- **Filtrage par IP, pas par interface** : les règles restent valides avec 1 ou 2 NIC.
- **Templates** : `templatefile()` génère le ruleset à partir des variables, donc aucune IP n'est écrite en dur.
- **Pas de NSG ni d'UDR dans ce module** : c'est le rôle de M3 (contrat d'interface).
- **Extensions de VM désactivées** par défaut (`allow_extension_operations = false`) pour réduire la surface d'attaque.
- **Alignement sur la matrice de flux de M3** : F01, F02, F06, F07, F08, F09, F12, F13 et F14 sont implémentés dans nftables.

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
| tout le VNet | vm-monitor | tcp 1514, 1515, 3100 | F08, `monitoring_ingest_tcp_ports` |
| bastion `10.10.3.4` | vm-monitor | tcp 3000 | F14 Grafana, `monitoring_ui_tcp_ports` |
| IP admin /32 (`admin_source_ips`) | NVA:2222 → **DNAT** bastion:22 | tcp | F06, **désactivé si la liste est vide** |
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
- **M1 (intégration)** : le subnet mgmt part en `0.0.0.0/0` via la NVA (UDR de M3), donc un SSH direct sur l'IP
  publique du bastion aura un retour asymétrique et sera bloqué. Accès admin prévu : passer les mêmes
  `admin_source_ips` à `module.firewall` et `module.routing`, puis `ssh -p 2222 <nva_public_ip>`.
- **M3** : le NSG firewall n'autorise pas monitoring → NVA `10.10.0.4:9100` (scrape de la NVA elle-même).
- **M4 (dmz)** : le site est publié via `nva_public_ip` (ports 80/443).
- **M5 (lan)** : l'app doit écouter sur `app_tcp_ports` (8080 par défaut), sinon ajuster la variable.
- **M6 (monitoring)** : scrape 9100, collecte 1514/1515/3100, Grafana 3000 par défaut ; output `nftables_ruleset` disponible pour des tests.

## Fins de ligne
`.gitattributes` force LF sur `*.sh` / `*.conf`, et `main.tf` retire les `\r` du custom_data :
un script en CRLF (`#!/bin/bash\r`) ne s'exécute pas sous cloud-init.

## Tests (`tests/firewall.tftest.hcl`)

| Test | Vérifie |
|---|---|
| `firewall_basic` | Nommage `vm-<prefix>-nva`, IP forwarding, mot de passe interdit, IP publique Standard statique |
| `firewall_static_ip_contract` | `nva_private_ip` = `10.10.0.4` dès le plan (nécessaire à M3) |
| `firewall_two_nics` / `firewall_single_nic` | 2 NIC par défaut, 1 si `enable_trust_nic = false` |
| `nftables_anti_lockout_and_policy` | SSH mgmt en 1re règle, policy drop sur input et forward, DNAT vers vm-web |
| `f06_disabled_by_default_f14_present` | Aucun DNAT SSH sans `admin_source_ips` ; F14 présent |
| `f06_admin_dnat_to_bastion` | NVA:2222 redirigé vers bastion:22 quand une IP admin est fournie |
| `custom_data_is_safe` | Syntaxe vérifiée avant application, pas de CRLF, shebang bash |
| `rejects_invalid_ip` / `rejects_invalid_port` / `rejects_admin_ip_not_32` | Les valeurs invalides sont refusées |

## Vérifier après déploiement (M1)

Depuis le bastion, `ssh azureuser@10.10.0.4` :

```bash
sudo cat /var/log/nva-install.log          # doit finir par "nftables appliqué" puis "fin"
sysctl net.ipv4.ip_forward                 # = 1
sudo nft list ruleset | head -40           # règles chargées, 1re règle input = anti-lockout
ip route | grep eth1                       # 10.10.0.0/16 via 10.10.0.1 dev eth1
sudo journalctl -k | grep nft-             # paquets refusés
```

Depuis Internet : `curl -I http://<nva_public_ip>` doit répondre (nginx de vm-web).

## Limites connues

- Pas encore déployé sur Azure : le ruleset a été relu, mais pas validé avec le vrai `nft -c`
  (pas de Linux sur le poste de dev). C'est la première chose à regarder dans `/var/log/nva-install.log`.
- Si `apt` échoue au premier boot (pas d'accès Internet), nftables n'est pas installé : la VM route
  sans filtrer. Le log l'indique clairement ; relancer avec `sudo bash /var/lib/cloud/instance/user-data.txt`.
- La route eth1 dépend du nommage `eth0`/`eth1` des images Ubuntu Azure ; si eth1 est absente,
  le script garde le routage par eth0 uniquement.
