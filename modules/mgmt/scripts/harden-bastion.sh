#!/bin/bash
# Exécuté au premier boot via cloud-init (custom_data).
set -eu
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y fail2ban unattended-upgrades nftables

cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'SSH'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 30
AllowAgentForwarding no
SSH
systemctl restart ssh

cat > /etc/fail2ban/jail.d/sshd.local <<'F2B'
[sshd]
enabled = true
maxretry = 4
bantime = 1h
F2B
systemctl enable --now fail2ban
