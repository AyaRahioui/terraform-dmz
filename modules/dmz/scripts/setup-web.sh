#!/bin/bash
# M4 vm-web first-boot configuration (Ubuntu 24.04, cloud-init).
# Terraform templatefile() replaces only: ${backend_ip}, ${backend_port}, ${bastion_ip}.
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
exec > >(tee -a /var/log/setup-web.log) 2>&1
trap 'echo "M4 setup failed at line $LINENO" >&2' ERR

BACKEND_IP='${backend_ip}'
BACKEND_PORT='${backend_port}'
BASTION_IP='${bastion_ip}'

apt-get update
apt-get install -y nginx libnginx-mod-http-modsecurity modsecurity-crs nftables openssl
printf 'server_tokens off;\n' > /etc/nginx/conf.d/hardening.conf

# Lab-only self-signed TLS certificate, generated locally (not committed to Git).
install -d -m 700 /etc/nginx/tls
openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 365 \
  -keyout /etc/nginx/tls/web.key -out /etc/nginx/tls/web.crt \
  -subj '/CN=vm-web'
chmod 600 /etc/nginx/tls/web.key

# Use the packaged ModSecurity recommended configuration when available.
install -d -m 755 /etc/nginx/modsec
if [ -f /etc/modsecurity/modsecurity.conf-recommended ]; then
  cp /etc/modsecurity/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf
elif [ -f /etc/modsecurity/modsecurity.conf ]; then
  cp /etc/modsecurity/modsecurity.conf /etc/nginx/modsec/modsecurity.conf
else
  echo 'ModSecurity base configuration not found' >&2
  exit 1
fi
# Append overrides so that the last setting enables prevention and audit logging.
cat >> /etc/nginx/modsec/modsecurity.conf <<'EOF'

SecRuleEngine On
SecRequestBodyAccess On
SecResponseBodyAccess Off
SecAuditEngine RelevantOnly
SecAuditLogType Serial
SecAuditLog /var/log/nginx/modsec_audit.log
EOF

# Discover the actual packaged CRS paths instead of assuming a single layout.
if [ -f /etc/modsecurity/crs/crs-setup.conf ]; then
  CRS_SETUP=/etc/modsecurity/crs/crs-setup.conf
elif [ -f /usr/share/modsecurity-crs/crs-setup.conf ]; then
  CRS_SETUP=/usr/share/modsecurity-crs/crs-setup.conf
elif [ -f /usr/share/modsecurity-crs/crs-setup.conf.example ]; then
  cp /usr/share/modsecurity-crs/crs-setup.conf.example /etc/nginx/modsec/crs-setup.conf
  CRS_SETUP=/etc/nginx/modsec/crs-setup.conf
else
  echo 'OWASP CRS setup file not found' >&2
  exit 1
fi
if [ -d /usr/share/modsecurity-crs/rules ]; then
  CRS_RULES=/usr/share/modsecurity-crs/rules
elif [ -d /etc/modsecurity/crs/rules ]; then
  CRS_RULES=/etc/modsecurity/crs/rules
else
  echo 'OWASP CRS rules directory not found' >&2
  exit 1
fi
cat > /etc/nginx/modsec/main.conf <<EOF
Include /etc/nginx/modsec/modsecurity.conf
Include $CRS_SETUP
Include $CRS_RULES/*.conf
EOF

# The quoted heredoc deliberately preserves Nginx $variables.
cat > /etc/nginx/sites-available/web.conf <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl default_server;
    server_name _;
    ssl_certificate /etc/nginx/tls/web.crt;
    ssl_certificate_key /etc/nginx/tls/web.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsec/main.conf;

    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Referrer-Policy "no-referrer" always;
    add_header Content-Security-Policy "default-src 'self'" always;

    location / {
        proxy_pass http://__BACKEND_IP__:__BACKEND_PORT__;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
EOF
sed -i -e "s/__BACKEND_IP__/$BACKEND_IP/g" \
       -e "s/__BACKEND_PORT__/$BACKEND_PORT/g" /etc/nginx/sites-available/web.conf
rm -f /etc/nginx/sites-enabled/default
ln -sfn /etc/nginx/sites-available/web.conf /etc/nginx/sites-enabled/web.conf
nginx -t
systemctl enable --now nginx
systemctl restart nginx

# SSH is restricted to key-based authentication; bastion IP is enforced below.
cat > /etc/ssh/sshd_config.d/10-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
MaxAuthTries 3
EOF
sshd -t
systemctl restart ssh

# Local firewall: incoming web from DNAT (original client IP retained),
# SSH only from bastion, Azure platform, established replies; default deny.
# Explicit outbound accept is needed for the backend proxy and updates.
cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        iifname "lo" accept
        ct state established,related accept comment "F13"
        ct state invalid drop comment "F12"
        ip saddr 168.63.129.16 accept comment "F10 Azure platform"
        tcp dport { 80, 443 } accept comment "F01 web"
        ip saddr __BASTION_IP__ tcp dport 22 accept comment "F07 bastion only"
        log prefix "NFT-WEB-DROP " level warn counter drop
    }
    chain forward {
        type filter hook forward priority filter; policy drop;
    }
    chain output {
        type filter hook output priority filter; policy accept;
    }
}
EOF
sed -i "s/__BASTION_IP__/$BASTION_IP/g" /etc/nftables.conf
nft -c -f /etc/nftables.conf
systemctl enable --now nftables
systemctl restart nftables

nginx -t
sshd -t
nft list ruleset
systemctl is-active --quiet nginx
systemctl is-active --quiet ssh
systemctl is-active --quiet nftables
echo 'M4 vm-web setup completed successfully'
