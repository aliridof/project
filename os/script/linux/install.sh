#!/bin/bash

###########################################
# Apache Guacamole Auto Installer (Universal)
# Supports: Debian/Ubuntu & RHEL/CentOS/Fedora
# Version: 3.2.0 - Fixed & Optimized
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

# Log files
LOG_FILE="/var/log/guacamole-installer.log"
DEBUG_LOG_FILE="/var/log/guacamole-installer-debug.log"
INSTALL_DIR="/opt/guacamole"
ENV_FILE="${INSTALL_DIR}/.env"
ERROR_FLAG="/tmp/guacamole_install_error"

# Global OS Detection Variables
PKG_MANAGER=""
PKG_UPDATE_CMD=""
PKG_INSTALL_CMD=""
SERVICE_CMD=""
FIREWALL_CMD=""

# Guacamole versions
GUAC_VERSION="1.5.5"
GUAC_SERVER_VERSION="1.5.5"
POSTGRES_JDBC_VERSION="42.7.3"

###########################################
# Helper Functions (Defined FIRST)
###########################################

print_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║     Apache Guacamole Auto Installer v3.2.0            ║"
    echo "║     Universal Linux - Fixed & Optimized               ║"
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
# Enhanced Logging Function
###########################################

log_command() {
    local cmd="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] EXECUTING: ${cmd}" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
}

# Set up the debug trap
trap 'log_command "$BASH_COMMAND"' DEBUG

###########################################
# OS Detection
###########################################

detect_os() {
    log_info "Mendeteksi sistem operasi dan manajer paket..."
    
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        PKG_UPDATE_CMD="apt-get update -y"
        PKG_INSTALL_CMD="apt-get install -y"
        SERVICE_CMD="systemctl"
        FIREWALL_CMD="ufw"
        log "✓ Distro berbasis APT terdeteksi (Debian/Ubuntu)"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        PKG_UPDATE_CMD="dnf update -y"
        PKG_INSTALL_CMD="dnf install -y"
        SERVICE_CMD="systemctl"
        FIREWALL_CMD="firewall-cmd"
        log "✓ Distro berbasis DNF terdeteksi (Fedora/RHEL/CentOS 8+)"
    elif command -v yum >/dev/null 2>&1; then
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
        if command -v systemctl >/dev/null 2>&1; then
            systemctl stop guacd 2>/dev/null || true
            systemctl stop tomcat* 2>/dev/null || true
            systemctl stop nginx 2>/dev/null || true
        fi
        
        # Mark error
        touch "$ERROR_FLAG"
        
        echo ""
        echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                                                        ║${NC}"
        echo -e "${RED}║   ✗ INSTALASI GAGAL                                   ║${NC}"
        echo -e "${RED}║                                                        ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${RED}🔍 UNTUK MENCARI PENYEBAB ERROR:${NC}"
        echo -e "   1. Lihat log utama untuk pesan error terakhir:"
        echo -e "      ${YELLOW}tail -n 50 ${LOG_FILE}${NC}"
        echo ""
        echo -e "   2. Lihat log debug untuk perintah yang GAGAL (baris terakhir):"
        echo -e "      ${YELLOW}tail -n 20 ${DEBUG_LOG_FILE}${NC}"
        echo ""
    fi
}

trap cleanup_on_error ERR EXIT

###########################################
# System Check Functions
###########################################

check_system_requirements() {
    log_info "Memeriksa sistem requirements..."
    
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local free_disk=$(df -m / | awk 'NR==2 {print $4}')
    
    if [[ $total_mem -lt 2048 ]]; then
        log_warning "RAM kurang dari 2GB, instalasi mungkin lambat"
    fi
    
    if [[ $free_disk -lt 5000 ]]; then
        log_warning "Disk space kurang dari 5GB, pastikan cukup ruang"
    fi
    
    log "✓ System requirements check completed"
}

get_public_ip() {
    local ip=""
    ip=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "")
    echo "$ip"
}

wait_for_service() {
    local service=$1
    local max_wait=${2:-30}
    local counter=0
    
    log_info "Menunggu $service siap..."
    
    while ! $SERVICE_CMD is-active --quiet "$service" 2>/dev/null; do
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

###########################################
# User Input Functions
###########################################

gather_user_input() {
    log_info "Mengumpulkan informasi konfigurasi..."
    
    mkdir -p "$INSTALL_DIR"
    
    # Database configuration
    read -p "Nama database [guacamole_db]: " DB_NAME
    DB_NAME=${DB_NAME:-guacamole_db}
    
    read -p "Username database [guacadmin]: " DB_USER
    DB_USER=${DB_USER:-guacadmin}
    
    read -sp "Password database: " DB_PASSWORD
    echo ""
    if [[ -z "$DB_PASSWORD" ]]; then
        DB_PASSWORD=$(openssl rand -base64 32)
        log_warning "Password auto-generated: ${DB_PASSWORD}"
    fi
    
    # Guacamole admin
    read -p "Username Guacamole admin [guacadmin]: " GUAC_ADMIN_USER
    GUAC_ADMIN_USER=${GUAC_ADMIN_USER:-guacadmin}
    
    read -sp "Password Guacamole admin: " GUAC_ADMIN_PASSWORD
    echo ""
    if [[ -z "$GUAC_ADMIN_PASSWORD" ]]; then
        GUAC_ADMIN_PASSWORD=$(openssl rand -base64 16)
        log_warning "Password admin auto-generated: ${GUAC_ADMIN_PASSWORD}"
    fi
    
    # Domain configuration
    read -p "Domain name (kosongkan untuk IP): " DOMAIN_NAME
    
    USE_SSL="no"
    if [[ -n "$DOMAIN_NAME" ]]; then
        read -p "Setup SSL dengan Let's Encrypt? (yes/no) [no]: " USE_SSL
        USE_SSL=${USE_SSL:-no}
    fi
    
    # Detect Tomcat version
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        TOMCAT_VERSION=$(apt-cache search tomcat | grep -oP 'tomcat\d+' | sort -V | tail -n1)
        TOMCAT_VERSION=${TOMCAT_VERSION:-tomcat10}
    else
        TOMCAT_VERSION="tomcat"
    fi
    
    # Save to env file
    cat > "$ENV_FILE" <<EOF
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
GUAC_ADMIN_USER=${GUAC_ADMIN_USER}
GUAC_ADMIN_PASSWORD=${GUAC_ADMIN_PASSWORD}
DOMAIN_NAME=${DOMAIN_NAME}
USE_SSL=${USE_SSL}
TOMCAT_VERSION=${TOMCAT_VERSION}
GUAC_VERSION=${GUAC_VERSION}
GUAC_SERVER_VERSION=${GUAC_SERVER_VERSION}
POSTGRES_JDBC_VERSION=${POSTGRES_JDBC_VERSION}
EOF
    
    chmod 600 "$ENV_FILE"
    log "✓ Konfigurasi disimpan ke $ENV_FILE"
}

###########################################
# Installation Functions
###########################################

install_dependencies() {
    log "Memperbarui sistem dan menginstal dependensi..."
    export DEBIAN_FRONTEND=noninteractive
    
    log_info "Menjalankan update paket..."
    eval "$PKG_UPDATE_CMD" >> "$LOG_FILE" 2>&1 || {
        log_error "Gagal update paket"
        return 1
    }
    
    source "$ENV_FILE"
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        log_info "Menginstal paket untuk sistem berbasis APT..."
        $PKG_INSTALL_CMD \
            build-essential libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin \
            libossp-uuid-dev libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
            freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev \
            libwebsockets-dev libpulse-dev libssl-dev libvorbis-dev libwebp-dev wget curl git \
            nginx postgresql postgresql-contrib openjdk-17-jdk ${TOMCAT_VERSION} ${TOMCAT_VERSION}-admin \
            certbot python3-certbot-nginx net-tools dnsutils iputils-ping \
            >> "$LOG_FILE" 2>&1 || {
                log_error "Gagal menginstal dependensi APT"
                return 1
            }
    else
        log_info "Menginstal epel-release..."
        $PKG_INSTALL_CMD epel-release >> "$LOG_FILE" 2>&1 || true
        
        log_info "Menginstal Development Tools..."
        $PKG_INSTALL_CMD @development-tools >> "$LOG_FILE" 2>&1 || {
            log_error "Gagal menginstal development tools"
            return 1
        }
        
        log_info "Menginstal paket dependensi lainnya..."
        $PKG_INSTALL_CMD \
            cairo-devel libjpeg-turbo-devel libpng-devel libtool uuid-devel \
            libavcodec-free-devel libavformat-free-devel libavutil-free-devel libswscale-free-devel \
            freerdp-devel pango-devel libssh2-devel libtelnet-devel libvncserver-devel \
            libwebsockets-devel pulseaudio-libs-devel openssl-devel libvorbis-devel libwebp-devel \
            wget curl git nginx postgresql-server postgresql-contrib java-17-openjdk-devel \
            ${TOMCAT_VERSION} certbot python3-certbot-nginx net-tools bind-utils iputils \
            >> "$LOG_FILE" 2>&1 || {
                log_error "Gagal menginstal dependensi DNF/YUM"
                return 1
            }
    fi
    
    log "✓ Dependensi berhasil diinstal"
}

setup_postgresql() {
    log "Mengkonfigurasi PostgreSQL..."
    source "$ENV_FILE"
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        $SERVICE_CMD start postgresql || {
            log_error "Gagal start PostgreSQL"
            return 1
        }
        $SERVICE_CMD enable postgresql
        wait_for_service postgresql || return 1
    else
        if [[ ! -d "/var/lib/pgsql/data" ]] || [[ -z "$(ls -A /var/lib/pgsql/data)" ]]; then
            log_info "Melakukan inisialisasi database PostgreSQL..."
            postgresql-setup --initdb >> "$LOG_FILE" 2>&1 || {
                log_error "Gagal inisialisasi PostgreSQL"
                return 1
            }
        fi
        
        $SERVICE_CMD start postgresql || {
            log_error "Gagal start PostgreSQL"
            return 1
        }
        $SERVICE_CMD enable postgresql
        wait_for_service postgresql || return 1
        
        sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' /var/lib/pgsql/data/pg_hba.conf 2>/dev/null || true
        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf 2>/dev/null || true
        
        $SERVICE_CMD restart postgresql
        wait_for_service postgresql || return 1
    fi
    
    # Create database and user
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME};" >> "$LOG_FILE" 2>&1 || log_warning "Database mungkin sudah ada"
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" >> "$LOG_FILE" 2>&1 || log_warning "User mungkin sudah ada"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" >> "$LOG_FILE" 2>&1
    
    log "✓ PostgreSQL berhasil dikonfigurasi"
}

install_guacamole_server() {
    log "Menginstal Guacamole Server ${GUAC_SERVER_VERSION}..."
    
    cd /tmp || exit 1
    
    # Download source
    if [[ ! -f "guacamole-server-${GUAC_SERVER_VERSION}.tar.gz" ]]; then
        wget "https://downloads.apache.org/guacamole/${GUAC_SERVER_VERSION}/source/guacamole-server-${GUAC_SERVER_VERSION}.tar.gz" \
            -O "guacamole-server-${GUAC_SERVER_VERSION}.tar.gz" >> "$LOG_FILE" 2>&1 || {
            log_error "Gagal download guacamole-server"
            return 1
        }
    fi
    
    tar -xzf "guacamole-server-${GUAC_SERVER_VERSION}.tar.gz"
    cd "guacamole-server-${GUAC_SERVER_VERSION}" || exit 1
    
    # Compile
    log_info "Kompilasi Guacamole Server (memakan waktu)..."
    ./configure --with-init-dir=/etc/init.d >> "$LOG_FILE" 2>&1 || {
        log_error "Configure gagal"
        return 1
    }
    
    make >> "$LOG_FILE" 2>&1 || {
        log_error "Make gagal"
        return 1
    }
    
    make install >> "$LOG_FILE" 2>&1 || {
        log_error "Make install gagal"
        return 1
    }
    
    ldconfig
    
    # Create systemd service
    cat > /etc/systemd/system/guacd.service <<EOF
[Unit]
Description=Guacamole Daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/sbin/guacd
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable guacd
    systemctl start guacd
    
    wait_for_service guacd || return 1
    
    log "✓ Guacamole Server berhasil diinstal"
}

install_guacamole_client() {
    log "Menginstal Guacamole Client ${GUAC_VERSION}..."
    source "$ENV_FILE"
    
    cd /tmp || exit 1
    
    # Download war file
    if [[ ! -f "guacamole-${GUAC_VERSION}.war" ]]; then
        wget "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war" \
            -O "guacamole-${GUAC_VERSION}.war" >> "$LOG_FILE" 2>&1 || {
            log_error "Gagal download guacamole client"
            return 1
        }
    fi
    
    # Setup directories
    mkdir -p /etc/guacamole/{extensions,lib}
    
    # Deploy war
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        cp "guacamole-${GUAC_VERSION}.war" "/var/lib/${TOMCAT_VERSION}/webapps/guacamole.war"
    else
        cp "guacamole-${GUAC_VERSION}.war" "/var/lib/tomcat/webapps/guacamole.war"
    fi
    
    # Download PostgreSQL JDBC driver
    if [[ ! -f "postgresql-${POSTGRES_JDBC_VERSION}.jar" ]]; then
        wget "https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar" \
            -O "postgresql-${POSTGRES_JDBC_VERSION}.jar" >> "$LOG_FILE" 2>&1 || {
            log_error "Gagal download JDBC driver"
            return 1
        }
    fi
    
    cp "postgresql-${POSTGRES_JDBC_VERSION}.jar" /etc/guacamole/lib/
    
    # Download and install PostgreSQL extension
    if [[ ! -f "guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz" ]]; then
        wget "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz" \
            -O "guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz" >> "$LOG_FILE" 2>&1 || {
            log_error "Gagal download auth-jdbc"
            return 1
        }
    fi
    
    tar -xzf "guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz"
    cp "guacamole-auth-jdbc-${GUAC_VERSION}/postgresql/guacamole-auth-jdbc-postgresql-${GUAC_VERSION}.jar" /etc/guacamole/extensions/
    
    # Initialize database schema
    cat "guacamole-auth-jdbc-${GUAC_VERSION}/postgresql/schema/"*.sql | \
        PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER}" -d "${DB_NAME}" >> "$LOG_FILE" 2>&1 || \
        log_warning "Schema mungkin sudah ada"
    
    log "✓ Guacamole Client berhasil diinstal"
}

configure_guacamole() {
    log "Mengkonfigurasi Guacamole..."
    source "$ENV_FILE"
    
    # Create guacamole.properties
    cat > /etc/guacamole/guacamole.properties <<EOF
# PostgreSQL properties
postgresql-hostname: localhost
postgresql-port: 5432
postgresql-database: ${DB_NAME}
postgresql-username: ${DB_USER}
postgresql-password: ${DB_PASSWORD}
postgresql-auto-create-accounts: true
EOF
    
    # Set environment variables
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        echo "GUACAMOLE_HOME=/etc/guacamole" >> "/etc/default/${TOMCAT_VERSION}"
    else
        echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/sysconfig/tomcat
    fi
    
    # Restart Tomcat
    $SERVICE_CMD restart ${TOMCAT_VERSION}
    wait_for_service ${TOMCAT_VERSION} 60 || return 1
    
    log "✓ Guacamole berhasil dikonfigurasi"
}

setup_nginx() {
    log "Mengkonfigurasi Nginx..."
    source "$ENV_FILE"
    
    local server_name="${DOMAIN_NAME:-$(get_public_ip)}"
    
    cat > /etc/nginx/sites-available/guacamole 2>/dev/null <<EOF || cat > /etc/nginx/conf.d/guacamole.conf <<EOF
server {
    listen 80;
    server_name ${server_name};
    
    location / {
        proxy_pass http://localhost:8080/guacamole/;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$http_connection;
        proxy_cookie_path /guacamole/ /;
        access_log off;
    }
}
EOF
    
    # Enable site (Debian/Ubuntu)
    if [[ -d /etc/nginx/sites-enabled ]]; then
        ln -sf /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
    fi
    
    nginx -t >> "$LOG_FILE" 2>&1 || {
        log_error "Nginx config test gagal"
        return 1
    }
    
    $SERVICE_CMD enable nginx
    $SERVICE_CMD restart nginx
    wait_for_service nginx || return 1
    
    log "✓ Nginx berhasil dikonfigurasi"
}

setup_ssl() {
    source "$ENV_FILE"
    
    if [[ "$USE_SSL" == "yes" ]] && [[ -n "$DOMAIN_NAME" ]]; then
        log "Mengkonfigurasi SSL dengan Let's Encrypt..."
        
        certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos --register-unsafely-without-email >> "$LOG_FILE" 2>&1 || {
            log_warning "SSL setup gagal, lanjut tanpa SSL"
            return 0
        }
        
        log "✓ SSL berhasil dikonfigurasi"
    fi
}

setup_firewall() {
    log "Mengkonfigurasi firewall..."
    
    if [[ "$FIREWALL_CMD" == "ufw" ]]; then
        if command -v ufw >/dev/null 2>&1; then
            ufw allow 22/tcp >> "$LOG_FILE" 2>&1 || true
            ufw allow 80/tcp >> "$LOG_FILE" 2>&1 || true
            ufw allow 443/tcp >> "$LOG_FILE" 2>&1 || true
            ufw --force enable >> "$LOG_FILE" 2>&1 || true
            log "✓ UFW firewall dikonfigurasi"
        fi
    elif [[ "$FIREWALL_CMD" == "firewall-cmd" ]]; then
        if command -v firewall-cmd >/dev/null 2>&1; then
            firewall-cmd --permanent --add-service=http >> "$LOG_FILE" 2>&1 || true
            firewall-cmd --permanent --add-service=https >> "$LOG_FILE" 2>&1 || true
            firewall-cmd --reload >> "$LOG_FILE" 2>&1 || true
            log "✓ firewalld dikonfigurasi"
        fi
    fi
}

verify_installation() {
    log "Memverifikasi instalasi..."
    
    local errors=0
    
    # Check guacd
    if ! systemctl is-active --quiet guacd; then
        log_error "guacd tidak berjalan"
        ((errors++))
    fi
    
    # Check Tomcat
    source "$ENV_FILE"
    if ! systemctl is-active --quiet ${TOMCAT_VERSION}; then
        log_error "Tomcat tidak berjalan"
        ((errors++))
    fi
    
    # Check Nginx
    if ! systemctl is-active --quiet nginx; then
        log_error "Nginx tidak berjalan"
        ((errors++))
    fi
    
    # Check database
    if ! systemctl is-active --quiet postgresql; then
        log_error "PostgreSQL tidak berjalan"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log "✓ Semua service berjalan normal"
        return 0
    else
        log_error "Ditemukan $errors error dalam verifikasi"
        return 1
    fi
}

print_installation_summary() {
    source "$ENV_FILE"
    
    local access_url="http://$(get_public_ip)"
    if [[ -n "$DOMAIN_NAME" ]]; then
        if [[ "$USE_SSL" == "yes" ]]; then
            access_url="https://${DOMAIN_NAME}"
        else
            access_url="http://${DOMAIN_NAME}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                        ║${NC}"
    echo -e "${GREEN}║   ✓ INSTALASI BERHASIL!                               ║${NC}"
    echo -e "${GREEN}║                                                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📋 INFORMASI AKSES:${NC}"
    echo -e "   URL: ${YELLOW}${access_url}${NC}"
    echo -e "   Username: ${YELLOW}${GUAC_ADMIN_USER}${NC}"
    echo -e "   Password: ${YELLOW}${GUAC_ADMIN_PASSWORD}${NC}"
    echo ""
    echo -e "${CYAN}📋 INFORMASI DATABASE:${NC}"
    echo -e "   Database: ${YELLOW}${DB_NAME}${NC}"
    echo -e "   User: ${YELLOW}${DB_USER}${NC}"
    echo -e "   Password: ${YELLOW}${DB_PASSWORD}${NC}"
    echo ""
    echo -e "${CYAN}📁 FILE KONFIGURASI:${NC}"
    echo -e "   Environment: ${YELLOW}${ENV_FILE}${NC}"
    echo -e "   Guacamole: ${YELLOW}/etc/guacamole/guacamole.properties${NC}"
    echo -e "   Nginx: ${YELLOW}/etc/nginx/sites-available/guacamole${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  PENTING: Simpan informasi ini dengan aman!${NC}"
    echo ""
}

###########################################
# Main Installation Function
###########################################

install_guacamole() {
    print_header
    check_root
    check_system_requirements
    detect_os
    
    gather_user_input
    
    log "Memulai instalasi Guacamole..."
    
    install_dependencies || exit 1
    setup_postgresql || exit 1
    install_guacamole_server || exit 1
    install_guacamole_client || exit 1
    configure_guacamole || exit 1
    setup_nginx || exit 1
    setup_ssl || exit 1
    setup_firewall || exit 1
    verify_installation || exit 1
    
    # Remove error flag if exists
    rm -f "$ERROR_FLAG"
    
    print_installation_summary
}

###########################################
# Rollback Function
###########################################

rollback_installation() {
    log_warning "Memulai rollback instalasi..."
    
    # Stop services
    systemctl stop guacd 2>/dev/null || true
