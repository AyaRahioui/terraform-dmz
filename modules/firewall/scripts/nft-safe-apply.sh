#!/bin/bash
# nft-safe-apply : applique un ruleset nftables avec ROLLBACK AUTOMATIQUE (anti-lockout).
#
# Usage (sur la NVA, via le bastion) :
#   sudo nft-safe-apply /tmp/nouveau.conf [delai_secondes]
#   -> les nouvelles règles sont actives ; si vous ne confirmez pas avec
#      "sudo nft-safe-apply --confirm" avant le délai (60 s par défaut),
#      l'ancien ruleset est restauré automatiquement.
#
# Le rollback est planifié par systemd (systemd-run) : il s'exécute même si la
# session SSH est coupée par les nouvelles règles.
set -euo pipefail

BACKUP=/var/lib/nva/nft-rollback.conf
UNIT=nft-rollback

if [ "${1:-}" = "--confirm" ]; then
  systemctl stop "$UNIT.timer" 2>/dev/null || true
  if [ -f /var/lib/nva/nft-pending.conf ]; then
    cp /var/lib/nva/nft-pending.conf /etc/nftables.conf
    rm -f /var/lib/nva/nft-pending.conf
  fi
  echo "[nft-safe-apply] confirmé : rollback annulé, /etc/nftables.conf mis à jour."
  exit 0
fi

NEW="${1:?usage: nft-safe-apply <fichier.conf> [delai] | --confirm}"
DELAY="${2:-60}"

mkdir -p /var/lib/nva
nft -c -f "$NEW"   # 1. vérification syntaxique : rien n'est appliqué si erreur

# 2. sauvegarde du ruleset actuel (avec flush pour une restauration atomique)
{ echo "flush ruleset"; nft list ruleset; } > "$BACKUP"

# 3. planification du rollback AVANT d'appliquer
systemctl stop "$UNIT.timer" 2>/dev/null || true
systemctl reset-failed "$UNIT.service" 2>/dev/null || true
systemd-run --quiet --unit="$UNIT" --on-active="$DELAY" /usr/sbin/nft -f "$BACKUP"

# 4. application
cp "$NEW" /var/lib/nva/nft-pending.conf
nft -f "$NEW"
echo "[nft-safe-apply] nouvelles règles actives. Rollback dans $DELAY s."
echo "[nft-safe-apply] si tout va bien : sudo nft-safe-apply --confirm"
