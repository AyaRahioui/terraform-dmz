#!/bin/bash
# vm-db: install PostgreSQL and make it listen on the private IP only.
set -euo pipefail

DB_IP="${DB_IP:-10.10.2.5}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y postgresql nftables

PG_DIR=$(ls -d /etc/postgresql/*/main | head -n1)
sed -i "s/^#\?listen_addresses.*/listen_addresses = 'localhost,${DB_IP}'/" "${PG_DIR}/postgresql.conf"