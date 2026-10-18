#!/bin/bash
# vm-db: database, least-privilege user, pg_hba.conf, then firewall.
set -euo pipefail

: "${DB_PASSWORD:?DB_PASSWORD is required}"
APP_IP="${APP_IP:-10.10.2.4}"
BASTION_IP="${BASTION_IP:-10.10.3.4}"

PG_DIR=$(ls -d /etc/postgresql/*/main | head -n1)

# Only vm-app may connect over the network, and only as app_user.
cat > "${PG_DIR}/pg_hba.conf" <<EOF
local   all      all                       peer
host    appdb    app_user   ${APP_IP}/32   scram-sha-256
EOF

systemctl restart postgresql

# Database + app_user with SELECT/INSERT/UPDATE only (no superuser, no DELETE).
sudo -u postgres psql -v ON_ERROR_STOP=1 -v pw="${DB_PASSWORD}" <<'SQL'
CREATE DATABASE appdb;
REVOKE ALL ON DATABASE appdb FROM PUBLIC;
CREATE ROLE app_user LOGIN PASSWORD :'pw';
GRANT CONNECT ON DATABASE appdb TO app_user;
\connect appdb
CREATE TABLE IF NOT EXISTS items (
  id serial PRIMARY KEY,
  name text NOT NULL,
  created_at timestamptz DEFAULT now()
);
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE ON items TO app_user;
GRANT USAGE, SELECT ON SEQUENCE items_id_seq TO app_user;
SQL

# Firewall: default DROP. Inbound: app -> 5432, bastion -> 22. No Internet.
# 168.63.129.16 and 169.254.169.254 are Azure platform services (needed by the VM agent).
cat > /etc/nftables.conf <<EOF
flush ruleset
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iif lo accept
    ip saddr ${APP_IP} tcp dport 5432 accept
    ip saddr ${BASTION_IP} tcp dport 22 accept
  }
  chain forward {
    type filter hook forward priority 0; policy drop;
  }
  chain output {
    type filter hook output priority 0; policy drop;
    ct state established,related accept
    oif lo accept
    ip daddr { 168.63.129.16, 169.254.169.254 } accept
  }
}
EOF
systemctl enable --now nftables
systemctl restart nftables