#!/bin/bash
set -euo pipefail

# ==============================================================
# Setup Guacamole + Docker + NGINX + UFW + TLS (Ubuntu 24.04 x86_64)
# Auto-generate docker-compose.yml, .env, nginx conf
# Usage:
#   sudo ./setup-guacamole.sh [your-domain.tld]
#   sudo ./setup-guacamole.sh --purge  → untuk uninstall penuh
# ==============================================================

progress(){
  local msg="$1"; local t=${2:-3}
  echo -ne "\033[33m$msg\033[0m "
  for i in $(seq 1 $t); do echo -n "▰"; sleep 0.3; done
  echo " ✅"
}

rollback(){
  echo "\n⚠️  Terjadi kesalahan. Memulai rollback..."
  docker compose -f /opt/guacamole-setup/docker-compose.yml down -v || true
  systemctl stop nginx || true
  rm -rf /opt/guacamole-setup /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/guacamole /etc/ssl/guacamole || true
  echo "Rollback selesai. Semua komponen Guacamole dihapus."
}

purge(){
  echo "\n🧹 Menghapus semua instalasi Guacamole..."
  docker compose -f /opt/guacamole-setup/docker-compose.yml down -v || true
  systemctl stop nginx || true
  rm -rf /opt/guacamole-setup /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/guacamole /etc/ssl/guacamole || true
  ufw delete allow 80/tcp || true
  ufw delete allow 443/tcp || true
  echo "✅ Uninstall penuh selesai."
  exit 0
}

trap rollback ERR

if [ "$EUID" -ne 0 ]; then echo "Jalankan memakai sudo/root"; exit 1; fi

# Mode purge
if [[ "${1:-}" == "--purge" ]]; then
  purge
fi

DOMAIN="${1:-}" # optional
INSTALL_DIR="/opt/guacamole-setup"
mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

progress "1. Update & install deps" 4
apt update
apt install -y curl gnupg lsb-release apt-transport-https software-properties-common 

# Install Docker if missing
if ! command -v docker >/dev/null; then
  progress "Install Docker" 5
  curl -fsSL https://get.docker.com | sh
fi
apt install -y docker-compose-plugin nginx certbot python3-certbot-nginx ufw

# Create .env
progress "2. Generate .env" 3
read -rsp "Masukkan password DB (min12, campuran): " PWD; echo
if [ ${#PWD} -lt 12 ]; then echo "Password terlalu pendek"; exit 1; fi
cat > .env <<EOF
POSTGRES_USER=guacamole_user
POSTGRES_DB=guacamole_db
POSTGRES_PASSWORD=$PWD
EOF
chmod 600 .env

# Generate docker-compose.yml
progress "3. Generate docker-compose.yml" 3
cat > docker-compose.yml <<'YAML'
version: "3.9"
services:
  db:
    image: postgres:15-alpine
    env_file: .env
    volumes: ["./db-data:/var/lib/postgresql/data"]
    restart: unless-stopped
  guacd:
    image: guacamole/guacd:1.5.3
    restart: unless-stopped
  guacamole:
    image: guacamole/guacamole:1.5.3
    env_file: .env
    ports: ["127.0.0.1:8080:8080"]
    depends_on: [db, guacd]
    restart: unless-stopped
YAML

# Start services
progress "4. Start docker compose" 5
docker compose up -d --wait

# Configure UFW
progress "5. Configure UFW" 3
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Nginx reverse proxy (bind to external)
progress "6. Configure NGINX" 4
NGINX_CONF="/etc/nginx/sites-available/guacamole"
cat > "$NGINX_CONF" <<EOF
server {
  listen 80;
  server_name ${DOMAIN:-_};
  location / {
    proxy_pass http://127.0.0.1:8080/guacamole/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
EOF
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/guacamole
nginx -t && systemctl reload nginx

# TLS: if domain provided, use certbot; else create self-signed
if [ -n "$DOMAIN" ]; then
  progress "7. Obtain LetsEncrypt cert" 5
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN || echo "Certbot gagal"
else
  progress "7. Create self-signed cert" 3
  mkdir -p /etc/ssl/guacamole
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/guacamole/guac.key -out /etc/ssl/guacamole/guac.crt -subj "/CN=$(curl -s https://api.ipify.org)"
  # simple HTTPS server block
  cat > /etc/nginx/sites-available/guacamole <<EOF
server {
  listen 80; server_name _; return 301 https://$host$request_uri;
}
server {
  listen 443 ssl;
  server_name _;
  ssl_certificate /etc/ssl/guacamole/guac.crt;
  ssl_certificate_key /etc/ssl/guacamole/guac.key;
  location / {
    proxy_pass http://127.0.0.1:8080/guacamole/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
EOF
  nginx -t && systemctl reload nginx
fi

# Show access URLs
INTERNAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s https://api.ipify.org || echo "Tidak tersedia")

echo "\n✅ Selesai. Akses Guacamole:"
echo "  Internal: http://$INTERNAL_IP:8080/guacamole/"
if [ -n "$DOMAIN" ]; then
echo "  Domain: https://$DOMAIN/"
else
  echo "  Publik (HTTPS self-signed): https://$PUBLIC_IP/"
fi

echo "Direktori: $INSTALL_DIR"
unset PWD

echo "\nCatatan: Jika menggunakan domain, pastikan A-record mengarah ke IP publik server."
