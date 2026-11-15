# T06/T07 — plan de preuves pour après intégration Azure

Ces tests NE sont PAS à faire avant la PR locale, puisque le groupe n'exige pas d'accès Azure individuel. Ils nécessitent `az login`, les noms réels des VM, Network Watcher dans la région et les permissions adéquates.

## T06 — Azure Network Watcher, Next hop

Vérifier le type `VirtualAppliance` et l'IP `10.10.0.4` pour :
1. web 10.10.1.4 -> app 10.10.2.4 ;
2. web 10.10.1.4 -> db 10.10.2.5 (routage via NVA mais filtrage DROP attendu) ;
3. web 10.10.1.4 -> monitor 10.10.4.4 ;
4. bastion 10.10.3.4 -> web 10.10.1.4 ;
5. monitor 10.10.4.4 -> LAN 10.10.2.4 ;
6. web 10.10.1.4 -> Internet (ex. 8.8.8.8).

Contrôle négatif : app 10.10.2.4 -> db 10.10.2.5 doit rester `VnetLocal` (même subnet), et passer par NSG LAN + firewall local ; pas par NVA.

Exemple (adapter noms et RG à l'environnement M1) :

```bash
az network watcher show-next-hop --resource-group "$RG" --vm "$VM_WEB" \
  --source-ip 10.10.1.4 --dest-ip 10.10.2.4 --output json
```

## T07 — Azure Network Watcher, IP flow verify

Tester `Allow` web:443 entrant, `Deny` web:22 depuis Internet, `Allow` web->app:8080, `Deny` web->db:5432, `Deny` web->bastion:22, `Allow` bastion->LAN:22, `Allow` app->db:5432 et `Deny` web->monitor:22. Vérifier le nom de règle qui a décidé, ainsi que les effective NSGs.

Exemple (adapter la VM, le RG, l'IP cliente et les ports) :

```bash
az network watcher test-ip-flow --resource-group "$RG" --vm "$VM_WEB" \
  --direction Outbound --protocol TCP \
  --local 10.10.1.4:51000 --remote 10.10.2.5:5432 --output json
```

Les anciens scripts `tests/routing/T06_next_hop.sh`, `T07_nsg_verify.sh` présents dans le ZIP utilisent l'ancien adressage et devront être adaptés **avec M1/M6**, et non exécutés tels quels. Les traces doivent avoir une date, une source/destination, un résultat observé et le résultat attendu.
