#!/usr/bin/env bash
# Run on application EC2 via Session Manager: sudo bash scripts/install-app.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${EUID}" -ne 0 ]]; then echo 'Run as root (sudo bash ...)'; exit 1; fi
if [[ -z "${DB_PASSWORD:-}" ]]; then
  read -r -s -p 'Enter the SAME PostgreSQL password used on DB tier: ' DB_PASSWORD
  printf '\n'
fi
if [[ ! "$DB_PASSWORD" =~ ^[A-Za-z0-9._@%+=:-]{12,}$ ]]; then
  echo 'Use at least 12 characters; allowed: letters, digits, dot, underscore, @, %, +, =, colon, hyphen.'; exit 1
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y python3 python3-venv python3-pip ca-certificates
if ! id -u shopbondhu >/dev/null 2>&1; then
  useradd --system --home-dir /opt/shopbondhu --shell /usr/sbin/nologin shopbondhu
fi
install -d -m 750 -o shopbondhu -g shopbondhu /opt/shopbondhu/api
cp "$ROOT/backend/app.py" "$ROOT/backend/requirements.txt" /opt/shopbondhu/api/
chown -R shopbondhu:shopbondhu /opt/shopbondhu
python3 -m venv /opt/shopbondhu/venv
/opt/shopbondhu/venv/bin/pip install --disable-pip-version-check -r /opt/shopbondhu/api/requirements.txt
install -d -m 750 -o root -g shopbondhu /etc/shopbondhu
# No shell interpolation in password; only newlines are disallowed.
umask 027
{
  printf 'DB_HOST=10.0.3.10\nDB_PORT=5432\nDB_NAME=shopbondhu_todo\nDB_USER=shopbondhu_user\n'
  printf 'DB_PASSWORD=%s\n' "$DB_PASSWORD"
} > /etc/shopbondhu/todo.env
chown root:shopbondhu /etc/shopbondhu/todo.env
chmod 640 /etc/shopbondhu/todo.env
unset DB_PASSWORD
cp "$ROOT/scripts/shopbondhu-api.service" /etc/systemd/system/shopbondhu-api.service
systemctl daemon-reload
systemctl enable --now shopbondhu-api
systemctl restart shopbondhu-api
printf '\nApp tier installed. Check: systemctl status shopbondhu-api --no-pager\n'
printf 'Then: curl -sS http://127.0.0.1:8000/api/health\n'
