# Module routing — M3 (UDR/NSG/NAT)

Responsable : **M3 (UDR/NSG/NAT)**

Tu travailles uniquement dans `modules/routing/`. Ne modifie pas `environments/dev` ni les autres modules.

## Contrat (ne pas casser)
- Variables : voir `variables.tf` (tu peux en AJOUTER avec une valeur par défaut, pas en renommer/supprimer).
- Outputs : voir `outputs.tf` (les noms sont utilisés par l'intégration). Remplace les placeholders par les vraies ressources.

## Démarrer
```bash
cd modules/routing
terraform init -backend=false
cd ../.. && ./check.sh modules/routing
```
Aucun compte Azure n'est nécessaire : les tests utilisent `mock_provider`.
