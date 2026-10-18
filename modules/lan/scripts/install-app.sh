#!/bin/bash
# vm-app: minimal Flask API (Web -> App -> DB), then firewall.
set -euo pipefail

: "${DB_PASSWORD:?DB_PASSWORD is required}"
DB_HOST="${DB_HOST:-10.10.2.5}"
DMZ_IP="${DMZ_IP:-10.10.1.4}"
BASTION_IP="${BASTION_IP:-10.10.3.4}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3-venv python3-pip nftables

# Collect the update-repo IPs NOW, while Internet is still allowed.
REPO_IPS=""
for h in azure.archive.ubuntu.com security.ubuntu.com; do
  ips=$(getent ahostsv4 "$h" | awk '{print $1}' | sort -u | paste -sd, - || true)
  [ -n "$ips" ] && REPO_IPS="${REPO_IPS:+$REPO_IPS,}$ips"
done

# Application
useradd --system --no-create-home --shell /usr/sbin/nologin appsvc || true
mkdir -p /opt/app
python3 -m venv /opt/app/venv
/opt/app/venv/bin/pip install flask psycopg2-binary gunicorn

cat > /opt/app/app.py <<'PY'
import os
import psycopg2
from flask import Flask, jsonify, request

app = Flask(__name__)

def db():
    return psycopg2.connect(
        host=os.environ["DB_HOST"], dbname="appdb", user="app_user",
        password=os.environ["DB_PASSWORD"], connect_timeout=3,
    )

@app.get("/health")
def health():
    return jsonify(status="ok")

@app.get("/items")
def list_items():
    with db() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, name FROM items ORDER BY id")
        return jsonify([{"id": r[0], "name": r[1]} for r in cur.fetchall()])

@app.post("/items")
def add_item():
    name = (request.get_json(silent=True) or {}).get("name", "")
    if not name:
        return jsonify(error="name required"), 400
    with db() as conn, conn.cursor() as cur:
        cur.execute("INSERT INTO items (name) VALUES (%s) RETURNING id", (name,))
        return jsonify(id=cur.fetchone()[0]), 201
PY

# Secrets live in a root-only env file, never in the code.
cat > /etc/app.env <<EOF
DB_HOST=${DB_HOST}
DB_PASSWORD=${DB_PASSWORD}
EOF
chmod 600 /etc/app.env
chown -R appsvc:appsvc /opt/app

cat > /etc/systemd/system/app.service <<'EOF'
[Unit]
Description=Minimal Flask API
After=network.target

[Service]
User=appsvc
WorkingDirectory=/opt/app
EnvironmentFile=/etc/app.env
ExecStart=/opt/app/venv/bin/gunicorn -w 2 -b 0.0.0.0:8080 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now app

# Firewall: inbound 8080 from the DMZ, 22 from the bastion.
# Outbound: DB 5432, DNS/Azure services, and update repos only.
REPO_RULE=""
[ -n "$REPO_IPS" ] && REPO_RULE="ip daddr { ${REPO_IPS} } tcp dport { 80, 443 } accept"

cat > /etc/nftables.conf <<EOF
flush ruleset
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iif lo accept
    ip saddr ${DMZ_IP} tcp dport 8080 accept
    ip saddr ${BASTION_IP} tcp dport 22 accept
  }
  chain forward {
    type filter hook forward priority 0; policy drop;
  }
  chain output {
    type filter hook output priority 0; policy drop;
    ct state established,related accept
    oif lo accept
    ip daddr ${DB_HOST} tcp dport 5432 accept
    ip daddr { 168.63.129.16, 169.254.169.254 } accept
    ${REPO_RULE}
  }
}
EOF
systemctl enable --now nftables
systemctl restart nftables