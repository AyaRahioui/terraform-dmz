# Matrice de flux M3 — draft pour revue d'équipe

Plan IP **réel du dépôt** : firewall 10.10.0.4, web 10.10.1.4, app 10.10.2.4, db 10.10.2.5, bastion 10.10.3.4, monitor 10.10.4.4. La surveillance est en **10.10.4.0/24**, pas dans la MGMT. Une règle NSG ne remplace pas le filtrage nftables M2 ni celui de chaque VM.

| ID | Source -> destination | Port(s) | Décision NSG M3 | Justification |
|---|---|---|---|---|
| F01 | Internet -> NVA 10.10.0.4 -> web 10.10.1.4 | TCP 80/443 | Allow (firewall+DMZ) | Publication HTTPS, HTTP réservé à la redirection ; la NVA doit faire le DNAT |
| F02 | web -> app | TCP 8080 | Allow DMZ sortant + LAN entrant | Reverse proxy vers l'API uniquement |
| F03 | app -> db | TCP 5432 | Allow LAN aller/retour stateful | DB intra-LAN protégée aussi par pare-feu hôte |
| F04 | DMZ -> LAN hors F02 | Tout | Deny | Anti-pivot, accès DB direct refusé |
| F05 | DMZ/LAN -> MGMT hors journalisation | Tout | Deny | Isolation de l'administration |
| F06 | IP équipe (/32) -> NVA 2222 -> bastion 22 | TCP 2222/22 | Allow seulement si admin_source_ips renseigné | SSH via IP autorisées, DNAT par M2 |
| F07 | bastion -> NVA et autres VM | TCP 22 | Allow | Administration via bastion |
| F08 | VM / NVA -> monitor 10.10.4.4 | TCP 1514/1515/3100 | Allow | Logs centralisés ; confirmer protocoles/ports M6 |
| F09 | DMZ/LAN/MGMT/MONITORING -> Internet | TCP 80/443 | Allow sous restriction | Mises à jour via SNAT/pare-feu M2 |
| F10 | VM -> 168.63.129.16 et IMDS 169.254.169.254 | 53, 80, 32526 selon destination | Allow ciblé | DNS/agent/metadata Azure |
| F11 | Internet -> autres services du firewall | Tout | Deny 4096 | Surface d'attaque réduite |
| F12 | Paquets invalides | Conntrack invalid | M2 nftables, hors NSG | Détection/refus de trafic invalide |
| F13 | Connexions établies | Established/related | Stateful NSG + M2 | Autoriser les réponses légitimes |
| F14 (à valider) | bastion -> monitor | TCP 3000 | Allow | Console Grafana accessible depuis le bastion uniquement |

**Points de vigilance :**
- Le NSG du subnet firewall laisse entrer les paquets *forwardés* depuis les zones internes uniquement vers les autres zones / Internet / services Azure spécifiés, pour que nftables décide en couche 2 ; éviter de confondre cette permission technique avec une autorisation inter-zones de bout en bout.
- Un DENY Azure NSG ne produit pas automatiquement les journaux `nftables` attendus par le dossier de cadrage ; la collecte de preuves doit séparer les deux couches.
- Le ZIP initial comporte des IP et un modèle two-NIC obsolètes : ne pas coller `configs/nftables/nva-nat.nft` ou `nva-routes-netplan.yaml` sans relecture de M2.
- La configuration ne prouve pas à elle seule que tout flux Internet traverse effectivement la NVA : vérifier en tests T06/T07, la topologie M2 et les routes effectives.

**Note F01/F06:** le NSG firewall autorise aussi la sortie des paquets apres DNAT vers web/bastion (source Internet ou CIDR admin conservee) ; verifier ce chemin dans T06/T07.
