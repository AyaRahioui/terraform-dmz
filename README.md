# Projet DMZ Azure — Terraform

## Qui fait quoi
| Membre | Module | Dossier |
|---|---|---|
| M1 | Réseau + bastion + intégration | `modules/network`, `modules/mgmt`, `environments/dev` |
| M2 | NVA firewall | `modules/firewall` |
| M3 | UDR / NSG / NAT | `modules/routing` |
| M4 | DMZ + WAF | `modules/dmz` |
| M5 | App + PostgreSQL | `modules/lan` |
| M6 | Monitoring + tests | `modules/monitoring` |

## Plan d'adressage (figé)
| Élément | Valeur |
|---|---|
| Région | germanywestcentral |
| VNet | 10.10.0.0/16 |
| snet firewall | 10.10.0.0/24 — NVA `10.10.0.4` |
| snet dmz | 10.10.1.0/24 — vm-web `10.10.1.4` |
| snet lan | 10.10.2.0/24 — vm-app `10.10.2.4`, vm-db `10.10.2.5` |
| snet mgmt | 10.10.3.0/24 — bastion `10.10.3.4` |
| snet monitoring | 10.10.4.0/24 — vm-monitor `10.10.4.4` |

(Azure réserve .0 à .3 de chaque subnet : la première IP utilisable est .4.)

## Règles (contrat d'interface)
1. Un module ne crée **ni Resource Group ni VNet** : il reçoit `resource_group_name`, `location`, `subnet_id`.
2. Noms prévisibles : `<type>-${var.name_prefix}-<rôle>`.
3. IP, tailles de VM, utilisateurs : **toujours des variables**.
4. On peut **ajouter** des variables/outputs, jamais renommer ou supprimer ceux du squelette.
5. Aucun secret, clé privée, subscription ID ou `.tfvars` dans Git. Seule la clé SSH **publique** est utilisée.
6. Scripts Linux dans `modules/<m>/scripts/` et chargés avec `file("${path.module}/scripts/...")`.
7. Les fichiers `tests/*.tftest.hcl` utilisent `mock_provider` : aucun accès Azure nécessaire.

## Workflow d'un membre (sans compte Azure)
```bash
git checkout -b feat/<ton-module>
cd modules/<ton-module>
terraform init -backend=false
cd ../..
./check.sh modules/<ton-module>     # fmt + validate + tflint + terraform test + checkov
git add . && git commit -m "feat(<module>): ..." && git push
```
Ouvrir une Pull Request vers `main` : M1 relit et intègre.

## Installation des outils
Terraform >= 1.7, TFLint, Checkov (`pip install checkov`).

## Intégration (M1 uniquement)
```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars   # puis éditer
az login
terraform init
terraform plan
```
Le backend (rg-tfstate-dmz / sttfstatedmz2026 / tfstate) n'est utilisé que par M1. Ne partagez aucune clé d'accès.
