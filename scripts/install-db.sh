#!/usr/bin/env bash
# Run on DB EC2 via Session Manager: sudo bash scripts/install-db.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${EUID}" -ne 0 ]]; then echo 'Run as root (sudo bash ...)'; exit 1; fi
if [[ -z "${DB_PASSWORD:-}" ]]; then
  read -r -s -p 'Choose a strong PostgreSQL password (remember it for app setup): ' DB_PASSWORD
  printf '\n'
fi
if [[ ! "$DB_PASSWORD" =~ ^[A-Za-z0-9._@%+=:-]{12,}$ ]]; then
  echo 'Use at least 12 characters; allowed: letters, digits, dot, underscore, @, %, +, =, colon, hyphen.'; exit 1
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y postgresql postgresql-client ca-certificates
systemctl enable --now postgresql
# Keep DB bound only to loopback and the fixed private IP assigned to its EC2.
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER SYSTEM SET listen_addresses = 'localhost,10.0.3.10'"
HBA_FILE="$(sudo -u postgres psql -At -c 'SHOW hba_file')"
HBA_ENTRY='host    shopbondhu_todo    shopbondhu_user    10.0.2.0/24    scram-sha-256'
if ! grep -Fqx "$HBA_ENTRY" "$HBA_FILE"; then
  printf '\n%s\n' "$HBA_ENTRY" >> "$HBA_FILE"
fi
# psql's :'db_pass' quotes the value as a SQL literal (not shell/SQL string concatenation).
sudo -u postgres psql -v ON_ERROR_STOP=1 -v db_pass="$DB_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE shopbondhu_user LOGIN PASSWORD %L', :'db_pass')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'shopbondhu_user') \gexec
SELECT format('ALTER ROLE shopbondhu_user LOGIN PASSWORD %L', :'db_pass')
WHERE EXISTS (SELECT FROM pg_roles WHERE rolname = 'shopbondhu_user') \gexec
SELECT 'CREATE DATABASE shopbondhu_todo OWNER shopbondhu_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'shopbondhu_todo') \gexec
SQL
sudo -u postgres psql -v ON_ERROR_STOP=1 -d shopbondhu_todo -f "$ROOT/database/schema.sql"
unset DB_PASSWORD
systemctl restart postgresql
printf '\nDatabase installed. Check with:\n'
printf "sudo -u postgres psql -d shopbondhu_todo -c 'SELECT * FROM tasks;'\n"
printf "sudo ss -lntp | grep 5432\n"
