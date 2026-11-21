#!/bin/bash
# custom_data (cloud-init) de la NVA — module firewall (M2).
# Rendu par templatefile() : les variables Terraform sont injectées par Terraform.
# 1. IP forwarding  2. nftables  3. route interne via eth1  4. outil anti-lockout
set -uo pipefail
exec >>/var/log/nva-install.log 2>&1
echo "[nva] début $(date -Is)"

# --- 1. IP forwarding + rp_filter souple (2 NIC dans le même subnet => routage asymétrique local)
cat >/etc/sysctl.d/99-nva.conf <<'SYSCTL_EOF'
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
SYSCTL_EOF
sysctl --system >/dev/null
echo "[nva] ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)"

# --- 2. nftables (ufw désactivé pour éviter deux pare-feux concurrents)
systemctl disable --now ufw 2>/dev/null || true
export DEBIAN_FRONTEND=noninteractive
for i in 1 2 3 4 5; do
  if command -v nft >/dev/null; then break; fi
  apt-get update -q && apt-get install -y -q nftables && break
  echo "[nva] apt échec (tentative $i), nouvel essai dans 15 s"
  sleep 15
done

cat >/etc/nftables.conf.new <<'NFT_CONF_EOF'
${nftables_conf}
NFT_CONF_EOF

NVA_IP="${nva_ip}"
if [ -z "$NVA_IP" ]; then
  NVA_IP=$(ip -4 -o addr show dev eth0 | awk '{print $4}' | cut -d/ -f1 | head -n1)
fi
sed -i "s/__NVA_IP__/$NVA_IP/" /etc/nftables.conf.new
echo "[nva] NVA_IP=$NVA_IP"

# ANTI-LOCKOUT : on n'applique QUE si la syntaxe est valide. Sinon on garde l'ancien état
# (accès SSH conservé) et on le signale clairement dans le log.
if command -v nft >/dev/null && nft -c -f /etc/nftables.conf.new; then
  mv /etc/nftables.conf.new /etc/nftables.conf
  chmod 0600 /etc/nftables.conf
  systemctl enable nftables
  systemctl restart nftables
  echo "[nva] nftables appliqué"
else
  echo "[nva] ERREUR : nftables non appliqué (nft absent ou config invalide) — voir ci-dessus"
fi

%{ if trust_nic_enabled ~}
# --- 3. Trafic vers le VNet par eth1 (trust), Internet par eth0 (untrust)
if ip link show eth1 >/dev/null 2>&1; then
  cat >/etc/netplan/60-nva-trust.yaml <<'NETPLAN_EOF'
network:
  version: 2
  ethernets:
    eth1:
      dhcp4: true
      # Pas de route par défaut via eth1 : Internet sort UNIQUEMENT par eth0 (SNAT).
      dhcp4-overrides:
        use-routes: false
        use-dns: false
      routes:
        - to: ${vnet_cidr}
          via: ${trust_gateway}
          metric: 50
NETPLAN_EOF
  chmod 0600 /etc/netplan/60-nva-trust.yaml
  if netplan generate; then
    netplan apply && echo "[nva] route ${vnet_cidr} via eth1 configurée"
  else
    echo "[nva] ERREUR netplan : fichier retiré, routage par eth0 uniquement"
    rm -f /etc/netplan/60-nva-trust.yaml
  fi
else
  echo "[nva] eth1 absente : routage par eth0 uniquement"
fi
%{ endif ~}

# --- 4. Outil de modification sûre des règles (rollback automatique)
cat >/usr/local/sbin/nft-safe-apply <<'SAFE_APPLY_EOF'
${safe_apply_script}
SAFE_APPLY_EOF
chmod 0750 /usr/local/sbin/nft-safe-apply

echo "[nva] fin $(date -Is)"
