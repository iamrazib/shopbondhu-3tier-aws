#!/usr/bin/env bash
# Run from repository root: sudo bash scripts/install-web.sh [--two-apps]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/nginx/shopbondhu.conf"
if [[ "${1:-}" == "--two-apps" ]]; then
  CONFIG="$ROOT/nginx/shopbondhu-bonus-two-apps.conf"
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y nginx ca-certificates
install -d -m 755 /var/www/shopbondhu
cp "$ROOT/frontend/"* /var/www/shopbondhu/
cp "$CONFIG" /etc/nginx/sites-available/shopbondhu
ln -sfn /etc/nginx/sites-available/shopbondhu /etc/nginx/sites-enabled/shopbondhu
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx
printf '\nWeb tier installed. Test http://PUBLIC_IP/ and http://PUBLIC_IP/api/health\n'
