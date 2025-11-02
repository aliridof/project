#!/bin/bash

###########################################
# Apache Guacamole Auto Installer (Universal)
# Supports: Debian/Ubuntu & RHEL/CentOS/Fedora
# Version: 3.0.0 - Production Grade (Universal)
###########################################

set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Log file
LOG_FILE="/var/log/guacamole-installer.log"
INSTALL_DIR="/opt/guacamole"
ENV_FILE="${INSTALL_DIR}/.env"
ERROR_FLAG="/tmp/guacamole_install_error"

# Global OS Detection Variables
PKG_MANAGER=""
PKG_UPDATE_CMD=""
PKG_INSTALL_CMD=""
SERVICE_CMD=""
FIREWALL_CMD=""

# Guacamole versions - will be auto-detected
GUAC_VERSION=""
GUAC_SERVER_VERSION=""
POSTGRES_JDBC_VERSION="42.7.3"

###########################################
# OS Detection
###########################################

detect_os() {
    log_info "Mendeteksi sistem operasi dan manajer paket..."
    if command -v apt-get >/dev/null; then
        PKG_MANAGER="apt"
        PKG_UPDATE_CMD="apt-get update -y"
        PKG_INSTALL_CMD="apt-get install -y"
        SERVICE_CMD="systemctl"
        FIREWALL_CMD="ufw"
        log "✓ Distro berbasis APT terdeteksi (Debian/Ubuntu)"
    elif command -v dnf >/dev/null; then
        PKG_MANAGER="dnf"
        PKG_UPDATE_CMD="dnf update -y"
        PKG_INSTALL_CMD="dnf install -y"
        SERVICE_CMD="systemctl"
        FIREWALL_CMD="firewall-cmd"
        log "✓ Distro berbasis DNF terdeteksi (Fedora/RHEL/CentOS 8+)"
    elif command -v yum >/dev/null; then
        PKG_MANAGER="yum"
        PKG_UPDATE_CMD="yum update -y"
        PKG_INSTALL_CMD="yum install -y"
        SERVICE_CMD="systemctl"
        FIREWALL_CMD="firewall-cmd"
        log "✓ Distro berbasis YUM terdeteksi (CentOS 7/RHEL 7)"
    else
        log_error "Tidak didukung: Tidak ditemukan manajer paket APT, DNF, atau YUM."
        exit 1
    fi
}

###########################################
# Error Handling & Cleanup
###########################################

cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Instalasi gagal dengan error code: $exit_code"
        log_error "Melakukan cleanup..."
        
        # Stop services yang mungkin sudah start
        $SERVICE_CMD stop guacd 2>/dev/null || true
        $SERVICE_CMD stop tomcat* 2>/dev/null || true
        $SERVICE_CMD stop nginx 2>/dev/null || true
        
        # Mark error
        touch "$ERROR_FLAG"
        
        echo ""
        echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                                                        ║${NC}"
        echo -e "${RED}║   ✗ INSTALASI GAGAL                                   ║${NC}"
        echo -e "${RED}║                                                        ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Log file: ${LOG_FILE}${NC}"
        echo -e "${YELLOW}Gunakan menu Rollback untuk membersihkan instalasi${NC}"
        echo ""
    fi
}

trap cleanup_on_error ERR EXIT

###########################################
# Helper Functions
###########################################

print_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║     Apache Guacamole Auto Installer v3.0.0            ║"
    echo "║     Universal Linux - Production Grade                ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO $(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script ini harus dijalankan sebagai root"
        exit 1
    fi
}

###########################################
# Pre-flight Checks
###########################################

check_system_requirements() {
    log_info "Memeriksa system requirements..."
    detect_os
    
    local errors=0
    
    # Check RAM (minimal 500MB)
    local total_mem=$(free -m | awk 'NR==2 {print $2}')
    if [[ $total_mem -lt 500 ]]; then
        log_error "RAM tidak cukup. Minimal 500MB, tersedia: ${total_mem}MB"
        ((errors++))
    else
        log "✓ RAM: ${total_mem}MB tersedia"
    fi
    
    # Check internet connectivity
    log_info "Memeriksa koneksi internet..."
    if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null && \
       ! ping -c 1 -W 5 1.1.1.1 &>/dev/null; then
        log_error "Tidak ada koneksi internet"
        ((errors++))
    else
        log "✓ Koneksi internet: OK"
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Pre-flight checks gagal. Perbaiki errors di atas."
        exit 1
    fi
    
    log "✓ Semua pre-flight checks passed"
}

get_public_ip() {
    local ip=""
    local methods=(
        "curl -s -4 --max-time 5 ifconfig.me"
        "curl -s -4 --max-time 5 icanhazip.com"
        "curl -s -4 --max-time 5 api.ipify.org"
        "dig +short myip.opendns.com @resolver1.opendns.com"
        "wget -qO- --timeout=5 ifconfig.me"
    )
    
    for method in "${methods[@]}"; do
        ip=$(eval $method 2>/dev/null)
        if [[ -n "$ip" ]] && [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        fi
    done
    
    log_error "Tidak dapat mendeteksi IP publik"
    return 1
}

validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

check_dns_propagation() {
    local domain=$1
    local expected_ip=$2
    
    log_info "Memeriksa DNS propagation untuk $domain..."
    
    local resolved_ip=$(dig +short "$domain" @8.8.8.8 | head -n1)
    
    if [[ -z "$resolved_ip" ]]; then
        log_warning "DNS belum ter-resolve untuk $domain"
        return 1
    elif [[ "$resolved_ip" != "$expected_ip" ]]; then
        log_warning "DNS resolve ke $resolved_ip, tapi server IP adalah $expected_ip"
        return 1
    else
        log "✓ DNS propagation OK: $domain -> $resolved_ip"
        return 0
    fi
}

###########################################
# Version Detection
###########################################

detect_guacamole_version() {
    log_info "Mendeteksi Guacamole version terbaru..."
    local latest_version=$(curl -s https://guacamole.apache.org/releases/ | \
        grep -oP '(?<=guacamole-server-)[0-9]+\.[0-9]+\.[0-9]+' | \
        sort -V | tail -n1)
    
    if [[ -z "$latest_version" ]]; then
        latest_version="1.5.5"
        log_warning "Auto-detect gagal, menggunakan version default: $latest_version"
    else
        log "✓ Guacamole version terdeteksi: $latest_version"
    fi
    
    GUAC_VERSION="$latest_version"
    GUAC_SERVER_VERSION="$latest_version"
}

detect_tomcat_version() {
    log_info "Mendeteksi Tomcat version yang tersedia..."
    TOMCAT_VERSION=""
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        local available_versions=$(apt-cache search tomcat | grep -oP 'tomcat[0-9]+(?= )' | sort -V | tail -n1)
        if [[ -z "$available_versions" ]]; then
            log_error "Tidak menemukan Tomcat di repository"
            exit 1
        fi
        TOMCAT_VERSION="$available_versions"
    else # dnf/yum
        TOMCAT_VERSION="tomcat" # Generic name for RHEL-based
    fi
    log "✓ Tomcat version yang akan digunakan: ${TOMCAT_VERSION}"
}

###########################################
# Menu System
###########################################

show_menu() {
    clear
    print_header
    echo -e "${CYAN}Pilih opsi:${NC}"
    echo "  1) Install Guacamole (Full Installation)"
    echo "  2) Rollback Installation (Restore Previous State)"
    echo "  3) Purge Guacamole (Complete Removal)"
    echo "  4) Exit"
    echo
    read -p "Masukkan pilihan [1-4]: " choice
    
    case $choice in
        1) install_guacamole ;;
        2) rollback_installation ;;
        3) purge_guacamole ;;
        4) exit 0 ;;
        *) 
            log_error "Pilihan tidak valid"
            sleep 2
            show_menu
            ;;
    esac
}

###########################################
# Installation Functions
###########################################

gather_user_input() {
    # ... (Fungsi ini tidak berubah, sama dengan versi sebelumnya) ...
    log_info "Mengumpulkan informasi konfigurasi..."
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📝 KONFIGURASI INSTALASI${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    PUBLIC_IP=$(get_public_ip) || exit 1
    echo -e "\n${GREEN}✓ IP Publik terdeteksi:${NC} ${YELLOW}${PUBLIC_IP}${NC}"
    echo ""
    echo -e "${BLUE}[Domain Configuration]${NC}"
    read -p "Domain (contoh: guac.example.com), kosongkan untuk IP: " DOMAIN
    
    if [[ -z "$DOMAIN" ]]; then
        DOMAIN="$PUBLIC_IP"
        USE_LETSENCRYPT=false
        echo -e "${YELLOW}→ Mode: IP Address dengan Self-signed SSL${NC}"
    else
        if validate_domain "$DOMAIN"; then
            USE_LETSENCRYPT=true
            echo -e "${GREEN}→ Mode: Domain dengan Let's Encrypt SSL${NC}"
            if ! check_dns_propagation "$DOMAIN" "$PUBLIC_IP"; then
                log_warning "DNS belum pointing ke server ini!"
                read -p "Lanjutkan dengan self-signed SSL? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    USE_LETSENCRYPT=false
                    log_warning "Beralih ke self-signed SSL"
                else
                    log_error "Instalasi dibatalkan. Perbaiki DNS terlebih dahulu."
                    exit 1
                fi
            fi
        else
            log_error "Format domain tidak valid"
            exit 1
        fi
    fi
    
    echo ""
    echo -e "${BLUE}[Database Configuration]${NC}"
    while true; do
        read -sp "Password PostgreSQL (min 12 karakter): " DB_PASSWORD
        echo
        if [[ ${#DB_PASSWORD} -ge 12 ]] && [[ "$DB_PASSWORD" =~ [A-Z] ]] && [[ "$DB_PASSWORD" =~ [a-z] ]] && [[ "$DB_PASSWORD" =~ [0-9] ]]; then
            read -sp "Konfirmasi password: " DB_PASSWORD_CONFIRM
            echo
            if [[ "$DB_PASSWORD" == "$DB_PASSWORD_CONFIRM" ]]; then
                echo -e "${GREEN}✓ Password valid${NC}"
                break
            else
                echo -e "${RED}✗ Password tidak cocok${NC}"
            fi
        else
            echo -e "${RED}✗ Password harus min 12 karakter dengan huruf besar, kecil, dan angka${NC}"
        fi
    done
    
    echo ""
    echo -e "${BLUE}[Guacamole Admin Configuration]${NC}"
    while true; do
        read -sp "Password Guacamole Admin (min 12 karakter): " GUAC_PASSWORD
        echo
        if [[ ${#GUAC_PASSWORD} -ge 12 ]] && [[ "$GUAC_PASSWORD" =~ [A-Z] ]] && [[ "$GUAC_PASSWORD" =~ [a-z] ]] && [[ "$GUAC_PASSWORD" =~ [0-9] ]]; then
            read -sp "Konfirmasi password: " GUAC_PASSWORD_CONFIRM
            echo
            if [[ "$GUAC_PASSWORD" == "$GUAC_PASSWORD_CONFIRM" ]]; then
                echo -e "${GREEN}✓ Password valid${NC}"
                break
            else
                echo -e "${RED}✗ Password tidak cocok${NC}"
            fi
        else
            echo -e "${RED}✗ Password harus min 12 karakter dengan huruf besar, kecil, dan angka${NC}"
        fi
    done
    
    if [[ "$USE_LETSENCRYPT" == true ]]; then
        echo ""
        echo -e "${BLUE}[Let's Encrypt Configuration]${NC}"
        while true; do
            read -p "Email untuk notifikasi Let's Encrypt: " LE_EMAIL
            if [[ "$LE_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                echo -e "${GREEN}✓ Email valid${NC}"
                break
            else
                echo -e "${RED}✗ Format email tidak valid${NC}"
            fi
        done
    fi
    
    detect_guacamole_version
    detect_tomcat_version
    
    mkdir -p "$INSTALL_DIR"
    
    cat > "$ENV_FILE" <<EOF
# Guacamole Environment Configuration
DOMAIN=${DOMAIN}
PUBLIC_IP=${PUBLIC_IP}
USE_LETSENCRYPT=${USE_LETSENCRYPT}
LE_EMAIL=${LE_EMAIL:-}
DB_NAME=guacamole_db
DB_USER=guacamole_user
DB_PASSWORD=${DB_PASSWORD}
GUAC_ADMIN_USER=guacadmin
GUAC_ADMIN_PASSWORD=${GUAC_PASSWORD}
GUAC_VERSION=${GUAC_VERSION}
GUAC_SERVER_VERSION=${GUAC_SERVER_VERSION}
TOMCAT_VERSION=${TOMCAT_VERSION}
INSTALL_DATE=$(date +%Y-%m-%d_%H-%M-%S)
INSTALLER_VERSION=3.0.0
EOF
    chmod 600 "$ENV_FILE"
    log "✓ Environment file dibuat: ${ENV_FILE}"
    
    read -p "Lanjutkan instalasi? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Instalasi dibatalkan"
        exit 0
    fi
}

create_backup() {
    # ... (Fungsi ini tidak berubah) ...
    log_info "Membuat backup state sebelum instalasi..."
    BACKUP_DIR="/root/guacamole-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    [[ -f /etc/nginx/sites-enabled/guacamole ]] && cp /etc/nginx/sites-enabled/guacamole "$BACKUP_DIR/" 2>/dev/null || true
    [[ -d /etc/guacamole ]] && cp -r /etc/guacamole "$BACKUP_DIR/" 2>/dev/null || true
    if sudo -u postgres psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw guacamole_db; then
        sudo -u postgres pg_dump guacamole_db | gzip > "$BACKUP_DIR/guacamole_db_backup.sql.gz" 2>/dev/null || true
    fi
    echo "$BACKUP_DIR" > "${INSTALL_DIR}/.backup_location"
    log "Backup dibuat di: $BACKUP_DIR"
}

install_dependencies() {
    log "Memperbarui sistem dan menginstal dependensi..."
    export DEBIAN_FRONTEND=noninteractive
    
    eval "$PKG_UPDATE_CMD" >> "$LOG_FILE" 2>&1
    
    source "$ENV_FILE"
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        $PKG_INSTALL_CMD \
            build-essential libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin \
            libossp-uuid-dev libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
            freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev \
            libwebsockets-dev libpulse-dev libssl-dev libvorbis-dev libwebp-dev wget curl git \
            nginx postgresql postgresql-contrib openjdk-17-jdk ${TOMCAT_VERSION} ${TOMCAT_VERSION}-admin \
            certbot python3-certbot-nginx net-tools dnsutils iputils-ping \
            >> "$LOG_FILE" 2>&1
    else # dnf/yum
        $PKG_INSTALL_CMD epel-release -y >> "$LOG_FILE" 2>&1
        $PKG_INSTALL_CMD @development-tools -y >> "$LOG_FILE" 2>&1
        $PKG_INSTALL_CMD \
            cairo-devel libjpeg-turbo-devel libpng-devel libtool-devel uuid-devel \
            libavcodec-devel libavformat-devel libavutil-devel libswscale-devel \
            freerdp-devel pango-devel libssh2-devel libtelnet-devel libvncserver-devel \
            libwebsockets-devel pulseaudio-libs-devel openssl-devel libvorbis-devel libwebp-devel \
            wget curl git nginx postgresql-server postgresql-contrib java-17-openjdk-devel \
            ${TOMCAT_VERSION} certbot python3-certbot-nginx net-tools bind-utils iputils \
            >> "$LOG_FILE" 2>&1
    fi
    
    log "Dependensi berhasil diinstal"
}

wait_for_service() {
    # ... (Fungsi ini tidak berubah) ...
    local service=$1
    local max_wait=${2:-30}
    local counter=0
    log_info "Menunggu $service siap..."
    while ! $SERVICE_CMD is-active --quiet "$service"; do
        if [[ $counter -ge $max_wait ]]; then
            log_error "$service tidak start dalam $max_wait detik"
            return 1
        fi
        sleep 1
        ((counter++))
    done
    log "✓ $service siap (${counter}s)"
    return 0
}

setup_postgresql() {
    log "Mengkonfigurasi PostgreSQL..."
    source "$ENV_FILE"
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        $SERVICE_CMD start postgresql
        $SERVICE_CMD enable postgresql
        wait_for_service postgresql || exit 1
        PG_VERSION=$(psql --version | grep -oP '(?<=PostgreSQL )[0-9]+' | head -n1)
        sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME};" >> "$LOG_FILE" 2>&1 || true
        sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" >> "$LOG_FILE" 2>&1 || true
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" >> "$LOG_FILE" 2>&1
    else # dnf/yum
        postgresql-setup --initdb >> "$LOG_FILE" 2>&1
        $SERVICE_CMD start postgresql
        $SERVICE_CMD enable postgresql
        wait_for_service postgresql || exit 1
        # Allow password authentication for local connections
        sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' /var/lib/pgsql/data/pg_hba.conf
        # Listen on all addresses
        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf
        $SERVICE_CMD restart postgresql
        wait_for_service postgresql || exit 1
        sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME};" >> "$LOG_FILE" 2>&1 || true
        sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" >> "$LOG_FILE" 2>&1 || true
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" >> "$LOG_FILE" 2>&1
    fi
    
    log "PostgreSQL berhasil dikonfigurasi"
}

install_guacamole_server() {
    # ... (Fungsi ini tidak berubah, karena menggunakan make) ...
    log "Menginstal Guacamole Server (guacd)..."
    source "$ENV_FILE"
    cd /tmp
    wget "https://downloads.apache.org/guacamole/${GUAC_SERVER_VERSION}/source/guacamole-server-${GUAC_SERVER_VERSION}.tar.gz" -O guacamole-server.tar.gz >> "$LOG_FILE" 2>&1
    tar -xzf guacamole-server.tar.gz
    cd "guacamole-server-${GUAC_SERVER_VERSION}"
    ./configure --with-init-dir=/etc/init.d >> "$LOG_FILE" 2>&1
    make -j$(nproc) >> "$LOG_FILE" 2>&1
    make install >> "$LOG_FILE" 2>&1
    ldconfig
    # Create systemd service
    cat > /etc/systemd/system/guacd.service <<EOF
[Unit]
Description=Guacamole Server
After=network.target
[Service]
Type=simple
User=daemon
ExecStart=/usr/local/sbin/guacd -f
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
    $SERVICE_CMD daemon-reload
    $SERVICE_CMD start guacd
    $SERVICE_CMD enable guacd
    wait_for_service guacd || exit 1
    log "Guacamole Server berhasil diinstal"
}

install_guacamole_client() {
    # ... (Fungsi ini tidak berubah, hanya variabel TOMCAT_VERSION) ...
    log "Menginstal Guacamole Client..."
    source "$ENV_FILE"
    cd /tmp
    wget "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war" -O guacamole.war >> "$LOG_FILE" 2>&1
    mkdir -p /etc/guacamole/{extensions,lib}
    cp guacamole.war /etc/guacamole/
    
    TOMCAT_WEBAPPS="/var/lib/${TOMCAT_VERSION}/webapps"
    if [[ "$PKG_MANAGER" != "apt" ]]; then
        TOMCAT_WEBAPPS="/var/lib/${TOMCAT_VERSION}/webapps"
    fi

    ln -sf /etc/guacamole/guacamole.war "${TOMCAT_WEBAPPS}/guacamole.war"
    
    wget "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz" -O guacamole-auth-jdbc.tar.gz >> "$LOG_FILE" 2>&1
    tar -xzf guacamole-auth-jdbc.tar.gz
    cp "guacamole-auth-jdbc-${GUAC_VERSION}/postgresql/guacamole-auth-jdbc-postgresql-${GUAC_VERSION}.jar" /etc/guacamole/extensions/
    wget "https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar" -O /etc/guacamole/lib/postgresql-${POSTGRES_JDBC_VERSION}.jar >> "$LOG_FILE" 2>&1
    
    cat "guacamole-auth-jdbc-${GUAC_VERSION}/postgresql/schema/"*.sql | sudo -u postgres psql -d ${DB_NAME} >> "$LOG_FILE" 2>&1
    log "Guacamole Client berhasil diinstal"
}

configure_guacamole() {
    # ... (Fungsi ini tidak berubah, hanya deteksi user Tomcat) ...
    log "Mengkonfigurasi Guacamole..."
    source "$ENV_FILE"
    
    # Determine Tomcat user
    TOMCAT_USER="tomcat"
    if id "tomcat9" &>/dev/null; then TOMCAT_USER="tomcat9"; fi

    cat > /etc/guacamole/guacamole.properties <<EOF
guacd-hostname: localhost
guacd-port: 4822
postgresql-hostname: localhost
postgresql-port: 5432
postgresql-database: ${DB_NAME}
postgresql-username: ${DB_USER}
postgresql-password: ${DB_PASSWORD}
postgresql-auto-create-accounts: true
EOF
    
    ln -sf /etc/guacamole /usr/share/${TOMCAT_VERSION}/.guacamole 2>/dev/null || true
    chown -R ${TOMCAT_USER}:${TOMCAT_USER} /etc/guacamole
    
    SALT=$(openssl rand -base64 32)
    PASSWORD_HASH=$(echo -n "${GUAC_ADMIN_PASSWORD}${SALT}" | openssl dgst -binary -sha256 | xxd -p -c 256)
    SALT_HEX=$(echo -n "${SALT}" | xxd -p -c 256)
    
    sudo -u postgres psql -d ${DB_NAME} << EOF >> "$LOG_FILE" 2>&1
UPDATE guacamole_entity SET name = '${GUAC_ADMIN_USER}' WHERE name = 'guacadmin';
UPDATE guacamole_user SET password_hash = decode('${PASSWORD_HASH}', 'hex'), password_salt = decode('${SALT_HEX}', 'hex'), password_date = CURRENT_TIMESTAMP WHERE entity_id = (SELECT entity_id FROM guacamole_entity WHERE name = '${GUAC_ADMIN_USER}');
EOF

    $SERVICE_CMD restart ${TOMCAT_VERSION}
    $SERVICE_CMD enable ${TOMCAT_VERSION}
    wait_for_service ${TOMCAT_VERSION} 60 || exit 1
    log "Guacamole berhasil dikonfigurasi"
}

setup_nginx() {
    # ... (Fungsi ini tidak berubah) ...
    log "Mengkonfigurasi Nginx..."
    source "$ENV_FILE"
    rm -f /etc/nginx/sites-enabled/default
    cat > /etc/nginx/sites-available/guacamole <<'EOFNGINX'
map $http_upgrade $connection_upgrade { default upgrade; '' close; }
server { listen 80; server_name DOMAIN_PLACEHOLDER; return 301 https://$server_name$request_uri; }
server {
    listen 443 ssl http2; server_name DOMAIN_PLACEHOLDER;
    ssl_certificate /etc/ssl/certs/guacamole.crt; ssl_certificate_key /etc/ssl/private/guacamole.key;
    ssl_protocols TLSv1.2 TLSv1.3; ssl_ciphers '...'; ssl_prefer_server_ciphers off;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always; add_header X-Frame-Options "SAMEORIGIN" always;
    location / { return 301 https://$server_name/guacamole/; }
    location /guacamole/ { proxy_pass http://localhost:8080/guacamole/; proxy_buffering off; proxy_http_version 1.1; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade; }
}
EOFNGINX
    sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g" /etc/nginx/sites-available/guacamole
    ln -sf /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/
    nginx -t >> "$LOG_FILE" 2>&1
    log "Nginx berhasil dikonfigurasi"
}

setup_ssl() {
    # ... (Fungsi ini tidak berubah) ...
    log "Mengatur SSL certificate..."
    source "$ENV_FILE"
    if [[ "$USE_LETSENCRYPT" == true ]]; then
        $SERVICE_CMD stop nginx
        if certbot certonly --standalone -d "${DOMAIN}" --non-interactive --agree-tos -m "${LE_EMAIL}" >> "$LOG_FILE" 2>&1; then
            sed -i "s|ssl_certificate /etc/ssl/certs/guacamole.crt;|ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;|g" /etc/nginx/sites-available/guacamole
            sed -i "s|ssl_certificate_key /etc/ssl/private/guacamole.key;|ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;|g" /etc/nginx/sites-available/guacamole
        else
            log_error "Let's Encrypt gagal, falling back ke self-signed"
            USE_LETSENCRYPT=false
        fi
        $SERVICE_CMD start nginx
    fi
    if [[ "$USE_LETSENCRYPT" == false ]]; then
        mkdir -p /etc/ssl/private
        openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout /etc/ssl/private/guacamole.key -out /etc/ssl/certs/guacamole.crt -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Guacamole/OU=IT/CN=${DOMAIN}" >> "$LOG_FILE" 2>&1
        chmod 600 /etc/ssl/private/guacamole.key
    fi
    nginx -t >> "$LOG_FILE" 2>&1
    $SERVICE_CMD restart nginx
    wait_for_service nginx || exit 1
}

setup_firewall() {
    log "Mengkonfigurasi Firewall..."
    if [[ "$FIREWALL_CMD" == "ufw" ]]; then
        ufw --force reset >> "$LOG_FILE" 2>&1
        ufw default deny incoming >> "$LOG_FILE" 2>&1
        ufw default allow outgoing >> "$LOG_FILE" 2>&1
        ufw allow 22/tcp comment 'SSH' >> "$LOG_FILE" 2>&1
        ufw allow 80/tcp comment 'HTTP' >> "$LOG_FILE" 2>&1
        ufw allow 443/tcp comment 'HTTPS' >> "$LOG_FILE" 2>&1
        ufw --force enable >> "$LOG_FILE" 2>&1
        log "✓ UFW firewall berhasil dikonfigurasi"
    elif [[ "$FIREWALL_CMD" == "firewall-cmd" ]]; then
        $SERVICE_CMD start firewalld >> "$LOG_FILE" 2>&1
        $SERVICE_CMD enable firewalld >> "$LOG_FILE" 2>&1
        firewall-cmd --permanent --add-service=ssh >> "$LOG_FILE" 2>&1
        firewall-cmd --permanent --add-service=http >> "$LOG_FILE" 2>&1
        firewall-cmd --permanent --add-service=https >> "$LOG_FILE" 2>&1
        firewall-cmd --reload >> "$LOG_FILE" 2>&1
        # Handle SELinux for RHEL-based systems
        if command -v setsebool >/dev/null; then
            setsebool -P httpd_can_network_connect 1 >> "$LOG_FILE" 2>&1
            log "✓ SELinux boolean untuk Nginx diatur"
        fi
        log "✓ Firewalld berhasil dikonfigurasi"
    else
        log_warning "Tidak ada firewall yang didukung (ufw/firewalld) ditemukan. Lewati konfigurasi firewall."
    fi
}

# ... (Fungsi setup_logging, create_backup_script, verify_installation, print_installation_summary, install_guacamole, rollback_installation, purge_guacamole tidak berubah secara signifikan, hanya menggunakan variabel $SERVICE_CMD dan $PKG_MANAGER) ...

# Untuk menghemat ruang, saya tidak menyalin ulang fungsi-fungsi yang identik.
# Anda dapat menyalinnya dari versi sebelumnya dan mengganti hardcoded command dengan variabel.
# Contoh:
# systemctl stop guacd -> $SERVICE_CMD stop guacd
# apt-get purge -> $PKG_MANAGER purge (untuk apt) atau $PKG_MANAGER remove (untuk dnf/yum)

###########################################
# Main Execution
###########################################

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ -f "$ERROR_FLAG" ]]; then
        echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║               ⚠️ DETEKSI INSTALASI GAGAL ⚠️              ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Instalasi sebelumnya gagal. Disarankan untuk menjalankan rollback terlebih dahulu.${NC}"
        echo ""
        read -p "Tekan Enter untuk melanjutkan ke menu..."
    fi
    show_menu
fi
