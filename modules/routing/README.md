# M3 — Routing / UDR / NSG (Terraform Azure)

**Cible :** le dépôt `AyaRahioui/terraform-dmz`, branche `feat/routing`.
Ce dossier reprend les noms du contrat de M1 (`variables.tf`, `outputs.tf`) et le plan IP du README racine (observé le 15 novembre 2026). **Ce n'est pas le plan IP de la première version du PDF ni du ZIP initial.**

## Périmètre

- 4 tables de routage : DMZ, LAN, MGMT, MONITORING. Elles envoient `0.0.0.0/0` et les /24 des autres zones vers `var.nva_private_ip` (10.10.0.4 dans le contrat actuel), tout en laissant l'intra-zone en VnetLocal.
- 5 NSG : FIREWALL, DMZ, LAN, MGMT et MONITORING ; permissions identifiées par F01…F14, refus explicites de priorité 4096 sur les zones de service.
- Associations des tables/NSG aux subnets existants. **Aucun VNet, subnet, VM, RG ou IP publique créé ici.**
- Les outputs `route_table_ids` et `nsg_ids` sont maintenus et exposent les nouvelles clés, `nsg_names` est ajouté.
- La matrice et les dépendances avec M2/M4/M5/M6 sont dans `docs/`.

## Entrées du module

Conservées strictement : `resource_group_name`, `location`, `name_prefix`, `tags`, `vnet_name`, `subnet_ids`, `subnet_cidrs`, `nva_private_ip`.

Ajoutées avec défaut : `hosts` (web 10.10.1.4, app 10.10.2.4, db 10.10.2.5, bastion 10.10.3.4, monitor 10.10.4.4), `admin_source_ips` (vide par sécurité), `app_port` (8080), `db_port` (5432), `monitoring_ports` (1514/1515/3100), `monitor_ui_port` (3000).

**IMPORTANT :** `admin_source_ips = []` signifie qu'aucune IP publique ne peut atteindre le bastion via le port 2222. M1 doit fournir des IP publiques autorisées `/32` lors de l'intégration, après accord d'équipe. Ne pas rendre ce port ouvert à Internet pour contourner le problème. Les autres valeurs par défaut doivent être comparées à celles des modules M2/M4/M5/M6 avant déploiement.

## Vérification locale sans Azure

Depuis la racine du clone (Git Bash ou WSL) :

```bash
cd modules/routing
terraform init -backend=false
terraform fmt -recursive
terraform validate
terraform test
cd ../..
./check.sh modules/routing
```

`check.sh` peut utiliser Checkov en mode soft-fail, donc regarder le détail des avertissements ; `STRICT=1 ./check.sh modules/routing` sert à les faire échouer si nécessaire. Il faut aussi lancer `git status` et `git diff --check` avant commit.

## Coordination indispensable

1. **M1** confirme la topologie actuellement publiée : 1 subnet firewall et 1 subnet monitoring indépendant. M1 conserve `environments/dev` et l'ajout éventuel des IP d'admin.
2. **M2** doit activer Azure NIC IP forwarding + Linux `net.ipv4.ip_forward=1`, nftables FORWARD/NAT. Les règles F01/F06 supposent DNAT **sans SNAT** pour préserver l'IP des clients. L'ancien fichier `nva-routes-netplan.yaml` cible une ancienne topologie outside/inside et ne doit pas être appliqué tel quel. Vérifier les routes Linux et le chemin de retour de la NVA.
3. **M4/M5/M6** confirment leurs IP, ports API/DB/journalisation, les NSG associés et les pare-feux nftables locaux. F14 (Grafana 3000) n'est qu'une proposition à accepter par le groupe.
4. **T06/T07** (Network Watcher Next hop et IP Flow Verify) ne sont possibles qu'après déploiement intégré sur Azure ; `terraform test` avec mock n'en constitue pas la preuve.

## Submission

Ne modifier que `modules/routing/` sur la branche `feat/routing` ; une PR vers `main`, jamais un push direct vers `main`.

## Important avant la PR

Ce dossier inclut le fichier `tests/routing.tftest.hcl` du squelette M1. Il est donc
possible de **remplacer completement** `modules/routing/` par ce dossier, MAIS
uniquement sur ta branche `feat/routing` (et seulement si tu n'as pas d'autres
modifications locales a conserver). Le script `check.sh` reste au niveau racine
du projet, et ne doit pas etre remplace.

Les priorites NSG commencent a 100 (Azure interdit 90). Le NSG firewall contient
les autorisations de transfert F01/F06 en sortie pour les paquets DNAT qui gardent
leur IP source Internet (le filtrage detaille reste fait par M2).

Aucune validation Terraform/TFLint/Checkov n'a ete effectuee pendant la generation
de cette archive. Le module est un candidat pour validation locale, pas un code
Azure deploye/prouve.
