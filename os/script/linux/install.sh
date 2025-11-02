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
BACKUP_DIR="/opt/guacamole-backup"

# Global OS Detection Variables
PKG_MANAGER=""
PKG_UPDATE_CMD=""
PKG_INSTALL_CMD=""
SERVICE_CMD="systemctl"
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
        echo -e "${RED}ERROR: Script ini harus dijalankan sebagai root${NC}"
        echo -e "${YELLOW}Gunakan: sudo $0${NC}"
        exit 1
    fi
}

###########################################
# Enhanced Logging Function
###########################################

log_command() {
    local cmd="$1"
    # Only log if debug log exists and is writable
    if [[ -w "$DEBUG_LOG_FILE" ]] 2>/dev/null; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] EXECUTING: ${cmd}" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
    fi
}

# Note: DEBUG trap will be set AFTER checking root and initializing logs

###########################################
# OS Detection
###########################################

detect_os() {
    log_info "Mendeteksi sistem operasi dan manajer paket..."
    
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        PKG_UPDATE_CMD="apt-get update -y"
        PKG_INSTALL_CMD="apt-get install -y"
        FIREWALL_CMD="ufw"
        log "✓ Distro berbasis APT terdeteksi (Debian/Ubuntu)"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        PKG_UPDATE_CMD="dnf update -y"
        PKG_INSTALL_CMD="dnf install -y"
        FIREWALL_CMD="firewall-cmd"
        log "✓ Distro berbasis DNF terdeteksi (Fedora/RHEL/CentOS 8+)"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        PKG_UPDATE_CMD="yum update -y"
        PKG_INSTALL_CMD="yum install -y"
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
    
    # Only run cleanup if it's actually an error (not normal exit)
    if [[ $exit_code -ne 0 ]] && [[ "$INSTALL_IN_PROGRESS" == "true" ]]; then
        log_error "Instalasi gagal dengan error code: $exit_code"
        log_error "Melakukan cleanup..."
        
        # Stop services yang mungkin sudah start
        systemctl stop guacd 2>/dev/null || true
        systemctl stop tomcat* 2>/dev/null || true
        systemctl stop nginx 2>/dev/null || true
        
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
        echo -e "   2. Lihat log debug untuk perintah yang GAGAL:"
        echo -e "      ${YELLOW}tail -n 20 ${DEBUG_LOG_FILE}${NC}"
        echo ""
        echo -e "   3. Jalankan rollback untuk membersihkan:"
        echo -e "      ${YELLOW}sudo $0${NC} (pilih opsi Rollback)"
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
        log_warning "RAM kurang dari 2GB (${total_mem}MB), instalasi mungkin lambat"
    fi
    
    if [[ $free_disk -lt 5000 ]]; then
        log_warning "Disk space kurang dari 5GB (${free_disk}MB tersedia)"
    fi
    
    log "✓ System requirements: RAM ${total_mem}MB, Disk ${free_disk}MB"
}

get_public_ip() {
    local ip=""
    ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || echo "localhost")
    echo "$ip"
}

wait_for_service() {
    local service=$1
    local max_wait=${2:-30}
    local counter=0
    
    log_info "Menunggu $service siap..."
    
    while ! systemctl is-active --quiet "$service" 2>/dev/null; do
        if [[ $counter -ge $max_wait ]]; then
            log_error "$service tidak start dalam $max_wait detik"
            systemctl status "$service" >> "$LOG_FILE" 2>&1 || true
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
    
    echo ""
    echo -e "${CYAN}=== Konfigurasi Database ===${NC}"
    read -p "Nama database [guacamole_db]: " DB_NAME
    DB_NAME=${DB_NAME:-guacamole_db}
    
    read -p "Username database [guacadmin]: " DB_USER
    DB_USER=${DB_USER:-guacadmin}
    
    read -sp "Password database (kosongkan untuk auto-generate): " DB_PASSWORD
    echo ""
    if [[ -z "$DB_PASSWORD" ]]; then
        DB_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 24)
        log_warning "Password database auto-generated"
    fi
    
    echo ""
    echo -e "${CYAN}=== Konfigurasi Guacamole Admin ===${NC}"
    read -p "Username Guacamole admin [guacadmin]: " GUAC_ADMIN_USER
    GUAC_ADMIN_USER=${GUAC_ADMIN_USER:-guacadmin}
    
    read -sp "Password Guacamole admin (kosongkan untuk auto-generate): " GUAC_ADMIN_PASSWORD
    echo ""
    if [[ -z "$GUAC_ADMIN_PASSWORD" ]]; then
        GUAC_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
        log_warning "Password admin auto-generated"
    fi
    
    echo ""
    echo -e "${CYAN}=== Konfigurasi Domain & SSL ===${NC}"
    read -p "Domain name (kosongkan untuk menggunakan IP): " DOMAIN_NAME
    
    USE_SSL="no"
    if [[ -n "$DOMAIN_NAME" ]]; then
        read -p "Setup SSL dengan Let's Encrypt? (yes/no) [no]: " USE_SSL
        USE_SSL=${USE_SSL:-no}
    fi
    
    # Detect Tomcat version
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        TOMCAT_VERSION=$(apt-cache search '^tomcat[0-9]+$' 2>/dev/null | grep -oP 'tomcat\d+' | sort -V | tail -n1)
        TOMCAT_VERSION=${TOMCAT_VERSION:-tomcat10}
    else
        TOMCAT_VERSION="tomcat"
    fi
    
    log_info "Tomcat version detected: $TOMCAT_VERSION"
    
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
        log_error "Gagal update paket, cek koneksi internet"
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
        $PKG_INSTALL_CMD groupinstall "Development Tools" >> "$LOG_FILE" 2>&1 || {
            log_error "Gagal menginstal development tools"
            return 1
        }
        
        log_info "Menginstal paket dependensi lainnya..."
        $PKG_INSTALL_CMD \
            cairo-devel libjpeg-turbo-devel libpng-devel libtool uuid-devel \
            ffmpeg-devel pango-devel libssh2-devel libtelnet-devel libvncserver-devel \
            libwebsockets-devel pulseaudio-libs-devel openssl-devel libvorbis-devel libwebp-devel \
            wget curl git nginx postgresql-server postgresql-contrib java-17-openjdk-devel \
            tomcat certbot python3-certbot-nginx net-tools bind-utils iputils \
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
        systemctl start postgresql || {
            log_error "Gagal start PostgreSQL"
            return 1
        }
        systemctl enable postgresql
        wait_for_service postgresql || return 1
    else
        if [[ ! -d "/var/lib/pgsql/data/base" ]]; then
            log_info "Melakukan inisialisasi database PostgreSQL..."
            postgresql-setup --initdb >> "$LOG_FILE" 2>&1 || {
                log_error "Gagal inisialisasi PostgreSQL"
                return 1
            }
        fi
        
        systemctl start postgresql || {
            log_error "Gagal start PostgreSQL"
            return 1
        }
        systemctl enable postgresql
        wait_for_service postgresql || return 1
        
        # Configure pg_hba.conf for password authentication
        sed -i 's/^local\s\+all\s\+all\s\+peer$/local   all             all                                     md5/' /var/lib/pgsql/data/pg_hba.conf 2>/dev/null || true
        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf 2>/dev/null || true
        
        systemctl restart postgresql
        wait_for_service postgresql || return 1
    fi
    
    # Create database and user
    log_info "Membuat database dan user..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${DB_NAME};" >> "$LOG_FILE" 2>&1 || true
    sudo -u postgres psql -c "DROP USER IF EXISTS ${DB_USER};" >> "$LOG_FILE" 2>&1 || true
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME};" >> "$LOG_FILE" 2>&1 || {
        log_error "Gagal membuat database"
        return 1
    }
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" >> "$LOG_FILE" 2>&1 || {
        log_error "Gagal membuat user database"
        return 1
    }
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" >> "$LOG_FILE" 2>&1
    sudo -u postgres psql -d "${DB_NAME}" -c "GRANT ALL ON SCHEMA public TO ${DB_USER};" >> "$LOG_FILE" 2>&1
    
    log "✓ PostgreSQL berhasil dikonfigurasi"
}

install_guacamole_server() {
    log "Menginstal Guacamole Server ${GUAC_SERVER_VERSION}..."
    
    cd /tmp || exit 1
    
    # Download source
    local tarball="guacamole-server-${GUAC_SERVER_VERSION}.tar.gz"
    if [[ ! -f "$tarball" ]]; then
        log_info "Downloading Guacamole Server..."
        wget "https://downloads.apache.org/guacamole/${GUAC_SERVER_VERSION}/source/${tarball}" \
            -O "$tarball" >> "$LOG_FILE" 2>&1 || {
            log_error "Gagal download guacamole-server"
            return 1
        }
    fi
    
    rm -rf "guacamole-server-${GUAC_SERVER_VERSION}"
    tar -xzf "$tarball"
    cd "guacamole-server-${GUAC_SERVER_VERSION}" || exit 1
    
    # Compile
    log_info "Kompilasi Guacamole Server (ini memakan waktu 5-10 menit)..."
    ./configure --with-init-dir=/etc/init.d >> "$LOG_FILE" 2>&1 || {
        log_error "Configure gagal, lihat $LOG_FILE"
        return 1
    }
    
    make -j$(nproc) >> "$LOG_FILE" 2>&1 || {
        log_error "Make gagal, lihat $LOG_FILE"
        return 1
    }
    
    make install >> "$LOG_FILE" 2>&1 || {
        log_error "Make install gagal"
        return 1
    }
    
    ldconfig
    
    # Create systemd service
    cat > /etc/systemd/system/guacd.service <<'EOFSERVICE'
[Unit]
Description=Guacamole Daemon
After=network.target

[Service]
Type=forking
Environment="GUACD_LOG_LEVEL=info"
ExecStart=/usr/local/sbin/guacd
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOFSERVICE
    
    systemctl daemon-reload
    systemctl enable guacd
    systemctl start guacd
    
    wait_for_service guacd 15 || {
        log_error "guacd gagal start"
        journalctl -u guacd -n 20 >> "$LOG_FILE" 2>&1
        return 1
    }
    
    log "✓ Guacamole Server berhasil diinstal"
}

install_guacamole_client() {
    log "Menginstal Guacamole Client ${GUAC_VERSION}..."
    source "$ENV_FILE"
    
    cd /tmp || exit 1
    
    # Download war file
    local warfile="guacamole-${GUAC_VERSION}.war"
    if [[ ! -f "$warfile" ]]; then
        log_info "Downloading Guacamole Client..."
        wget "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/${warfile}" \
            -O "$warfile" >> "$LOG_FILE" 2>&1 || {
            log_error "Gagal download guacamole client"
            return 1
        }
    fi
    
    # Setup directories
    mkdir -p /etc/guacamole/{extensions,lib}
    
    # Deploy war
    local webapps_dir=""
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        webapps_dir="/var/lib/${TOMCAT_VERSION}/webapps"
    else
        webapps_dir="/var/lib/tomcat/webapps"
    fi
    
    mkdir -p "$webapps_dir"
    cp "$warfile" "${webapps_dir}/guacamole.war"
    
    # Download PostgreSQL JDBC driver
    local jdbc_jar="postgresql-${POSTGRES_JDBC_VERSION}.jar"
    if [[ ! -f "$jdbc_jar" ]]; then
        log_info "Downloading PostgreSQL JDBC driver..."
        wget "https://jdbc.postgresql.org/download/${jdbc_jar}" \
            -O "$jdbc_jar" >> "$LOG_FILE" 2>&1 || {
            log_error "Gagal download JDBC driver"
            return 1
        }
    fi
    
    cp "$jdbc_jar" /etc/guacamole/lib/
    
    # Download and install PostgreSQL extension
    local auth_jdbc="guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz"
    if [[ ! -f "$auth_jdbc" ]]; then
        log_info "Downloading Guacamole Auth JDBC..."
        wget "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/${auth_jdbc}" \
            -O "$auth_jdbc" >> "$LOG_FILE" 2>&1 || {
            log_error "Gagal download auth-jdbc"
            return 1
        }
    fi
    
    rm -rf "guacamole-auth-jdbc-${GUAC_VERSION}"
    tar -xzf "$auth_jdbc"
    cp "guacamole-auth-jdbc-${GUAC_VERSION}/postgresql/guacamole-auth-jdbc-postgresql-${GUAC_VERSION}.jar" /etc/guacamole/extensions/
    
    # Initialize database schema
    log_info "Menginisialisasi database schema..."
    cat "guacamole-auth-jdbc-${GUAC_VERSION}/postgresql/schema/"*.sql | \
        PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER}" -d "${DB_NAME}" >> "$LOG_FILE" 2>&1 || {
        log_error "Gagal inisialisasi schema database"
        return 1
    }
    
    log "✓ Guacamole Client berhasil diinstal"
}

configure_guacamole() {
    log "Mengkonfigurasi Guacamole..."
    source "$ENV_FILE"
    
    # Create guacamole.properties
    cat > /etc/guacamole/guacamole.properties <<EOFPROP
# PostgreSQL properties
postgresql-hostname: localhost
postgresql-port: 5432
postgresql-database: ${DB_NAME}
postgresql-username: ${DB_USER}
postgresql-password: ${DB_PASSWORD}
postgresql-auto-create-accounts: true
EOFPROP
    
    # Set correct permissions
    chmod 600 /etc/guacamole/guacamole.properties
    
    # Set environment variables
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        echo "GUACAMOLE_HOME=/etc/guacamole" >> "/etc/default/${TOMCAT_VERSION}"
    else
        echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/sysconfig/tomcat
    fi
    
    # Restart Tomcat
    log_info "Restarting Tomcat..."
    systemctl restart ${TOMCAT_VERSION}
    wait_for_service ${TOMCAT_VERSION} 60 || {
        log_error "Tomcat gagal start"
        journalctl -u ${TOMCAT_VERSION} -n 30 >> "$LOG_FILE" 2>&1
        return 1
    }
    
    log "✓ Guacamole berhasil dikonfigurasi"
}

setup_nginx() {
    log "Mengkonfigurasi Nginx..."
    source "$ENV_FILE"
    
    local server_name="${DOMAIN_NAME:-$(get_public_ip)}"
    
    # Determine nginx config location
    local nginx_conf=""
    if [[ -d /etc/nginx/sites-available ]]; then
        nginx_conf="/etc/nginx/sites-available/guacamole"
    else
        nginx_conf="/etc/nginx/conf.d/guacamole.conf"
    fi
    
    cat > "$nginx_conf" <<EOFNGINX
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
EOFNGINX
    
    # Enable site (Debian/Ubuntu)
    if [[ -d /etc/nginx/sites-enabled ]]; then
        ln -sf /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
    fi
    
    nginx -t >> "$LOG_FILE" 2>&1 || {
        log_error "Nginx config test gagal"
        cat "$nginx_conf" >> "$LOG_FILE"
        return 1
    }
    
    systemctl enable nginx
    systemctl restart nginx
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
    else
        log_info "SSL tidak dikonfigurasi (USE_SSL=$USE_SSL, DOMAIN=$DOMAIN_NAME)"
    fi
}

setup_firewall() {
    log "Mengkonfigurasi firewall..."
    
    if [[ "$FIREWALL_CMD" == "ufw" ]] && command -v ufw >/dev/null 2>&1; then
        ufw --force allow 22/tcp >> "$LOG_FILE" 2>&1 || true
        ufw --force allow 80/tcp >> "$LOG_FILE" 2>&1 || true
        ufw --force allow 443/tcp >> "$LOG_FILE" 2>&1 || true
        echo "y" | ufw enable >> "$LOG_FILE" 2>&1 || true
        log "✓ UFW firewall dikonfigurasi"
    elif [[ "$FIREWALL_CMD" == "firewall-cmd" ]] && command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-service=http >> "$LOG_FILE" 2>&1 || true
        firewall-cmd --permanent --add-service=https >> "$LOG_FILE" 2>&1 || true
        firewall-cmd --permanent --add-service=ssh >> "$LOG_FILE" 2>&1 || true
        firewall-cmd --reload >> "$LOG_FILE" 2>&1 || true
        log "✓ firewalld dikonfigurasi"
    else
        log_warning "Firewall tidak tersedia atau tidak dikonfigurasi"
    fi
}

verify_installation() {
    log "Memverifikasi instalasi..."
    
    local errors=0
    
    # Check guacd
    if ! systemctl is-active --quiet guacd; then
        log_error "guacd tidak berjalan"
        ((errors++))
    else
        log_info "✓ guacd running"
    fi
    
    # Check Tomcat
    source "$ENV_FILE"
    if ! systemctl is-active --quiet ${TOMCAT_VERSION}; then
        log_error "Tomcat tidak berjalan"
        ((errors++))
    else
        log_info "✓ Tomcat running"
    fi
    
    # Check Nginx
    if ! systemctl is-active --quiet nginx; then
        log_error "Nginx tidak berjalan"
        ((errors++))
    else
        log_info "✓ Nginx running"
    fi
    
    # Check database
    if ! systemctl is-active --quiet postgresql; then
        log_error "PostgreSQL tidak berjalan"
        ((errors++))
    else
        log_info "✓ PostgreSQL running"
    fi
    
    # Test Guacamole endpoint
    sleep 5
    if curl -s http://localhost:8080/guacamole/ | grep -q "Guacamole" 2>/dev/null; then
        log_info "✓ Guacamole web interface accessible"
    else
        log_warning "Guacamole web interface belum siap, tunggu beberapa detik"
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
    # Set flag to indicate installation is in progress
    INSTALL_IN_PROGRESS="true"
    
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
    verify_installation || log_warning "Beberapa service mungkin perlu waktu untuk start"
    
    # Installation successful
    INSTALL_IN_PROGRESS="false"
    
    # Remove error flag if exists
    rm -f "$ERROR_FLAG"
    
    print_installation_summary
}

###########################################
# Rollback Function
###########################################

rollback_installation() {
    print_header
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                        ║${NC}"
    echo -e "${RED}║   ⚠️  ROLLBACK INSTALASI                              ║${NC}"
    echo -e "${RED}║                                                        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Ini akan menghapus semua komponen Guacamole yang terinstal.${NC}"
    echo -e "${YELLOW}Data dan konfigurasi akan dihapus!${NC}"
    echo ""
    read -p "Apakah Anda yakin ingin melanjutkan? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log "Rollback dibatalkan"
        return 0
    fi
    
    log "Memulai rollback..."
    
    # Stop services
    log_info "Menghentikan services..."
    systemctl stop guacd 2>/dev/null || true
    systemctl stop tomcat* 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    systemctl stop postgresql 2>/dev/null || true
    
    # Disable services
    systemctl disable guacd 2>/dev/null || true
    systemctl disable nginx 2>/dev/null || true
    
    # Remove Guacamole Server
    log_info "Menghapus Guacamole Server..."
    rm -f /usr/local/sbin/guacd
    rm -f /usr/local/lib/libguac*
    rm -rf /usr/local/lib/freerdp2
    rm -f /etc/systemd/system/guacd.service
    
    # Remove Guacamole Client
    log_info "Menghapus Guacamole Client..."
    rm -rf /etc/guacamole
    rm -f /var/lib/tomcat*/webapps/guacamole.war
    rm -rf /var/lib/tomcat*/webapps/guacamole
    
    # Remove database (optional)
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE"
        log_info "Menghapus database..."
        sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null || true
        sudo -u postgres psql -c "DROP USER IF EXISTS ${DB_USER};" 2>/dev/null || true
    fi
    
    # Remove nginx config
    log_info "Menghapus konfigurasi Nginx..."
    rm -f /etc/nginx/sites-available/guacamole
    rm -f /etc/nginx/sites-enabled/guacamole
    rm -f /etc/nginx/conf.d/guacamole.conf
    
    # Remove installation directory
    log_info "Menghapus direktori instalasi..."
    rm -rf "$INSTALL_DIR"
    
    # Remove error flag
    rm -f "$ERROR_FLAG"
    
    # Reload systemd
    systemctl daemon-reload
    
    log "✓ Rollback selesai"
    echo ""
    echo -e "${GREEN}Rollback berhasil! Semua komponen Guacamole telah dihapus.${NC}"
    echo ""
}

###########################################
# Purge Function (Complete Removal)
###########################################

purge_guacamole() {
    print_header
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                        ║${NC}"
    echo -e "${RED}║   ⚠️  PURGE COMPLETE - HAPUS SEMUA                    ║${NC}"
    echo -e "${RED}║                                                        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Ini akan menghapus SEMUA termasuk:${NC}"
    echo -e "  - Guacamole Server & Client"
    echo -e "  - PostgreSQL, Nginx, Tomcat (termasuk paket)"
    echo -e "  - Semua konfigurasi dan data"
    echo ""
    read -p "Apakah Anda YAKIN ingin melanjutkan? (type 'DELETE' to confirm): " confirm
    
    if [[ "$confirm" != "DELETE" ]]; then
        log "Purge dibatalkan"
        return 0
    fi
    
    log "Memulai purge lengkap..."
    
    # Run rollback first
    rollback_installation
    
    # Remove packages
    detect_os
    
    log_info "Menghapus paket yang terinstal..."
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        apt-get purge -y postgresql* tomcat* nginx certbot python3-certbot-nginx 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        apt-get autoclean -y 2>/dev/null || true
    else
        yum remove -y postgresql* tomcat* nginx certbot python3-certbot-nginx 2>/dev/null || true
        yum autoremove -y 2>/dev/null || true
    fi
    
    # Remove data directories
    log_info "Menghapus direktori data..."
    rm -rf /var/lib/postgresql
    rm -rf /var/lib/pgsql
    rm -rf /var/lib/tomcat*
    rm -rf /etc/postgresql
    rm -rf /etc/nginx
    
    # Remove logs
    rm -f "$LOG_FILE"
    rm -f "$DEBUG_LOG_FILE"
    
    log "✓ Purge lengkap selesai"
    echo ""
    echo -e "${GREEN}Purge berhasil! Semua komponen telah dihapus dari sistem.${NC}"
    echo ""
}

###########################################
# Status Check Function
###########################################

check_status() {
    print_header
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║   📊 STATUS GUACAMOLE                                 ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check if installed
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}❌ Guacamole belum terinstal${NC}"
        echo ""
        return 1
    fi
    
    source "$ENV_FILE"
    
    echo -e "${CYAN}🔧 Service Status:${NC}"
    
    # Check guacd
    if systemctl is-active --quiet guacd 2>/dev/null; then
        echo -e "   guacd: ${GREEN}✓ Running${NC}"
    else
        echo -e "   guacd: ${RED}✗ Stopped${NC}"
    fi
    
    # Check Tomcat
    if systemctl is-active --quiet ${TOMCAT_VERSION} 2>/dev/null; then
        echo -e "   ${TOMCAT_VERSION}: ${GREEN}✓ Running${NC}"
    else
        echo -e "   ${TOMCAT_VERSION}: ${RED}✗ Stopped${NC}"
    fi
    
    # Check Nginx
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "   nginx: ${GREEN}✓ Running${NC}"
    else
        echo -e "   nginx: ${RED}✗ Stopped${NC}"
    fi
    
    # Check PostgreSQL
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        echo -e "   postgresql: ${GREEN}✓ Running${NC}"
    else
        echo -e "   postgresql: ${RED}✗ Stopped${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}📋 Konfigurasi:${NC}"
    echo -e "   Database: ${YELLOW}${DB_NAME}${NC}"
    echo -e "   DB User: ${YELLOW}${DB_USER}${NC}"
    echo -e "   Admin User: ${YELLOW}${GUAC_ADMIN_USER}${NC}"
    echo -e "   Domain: ${YELLOW}${DOMAIN_NAME:-$(get_public_ip)}${NC}"
    echo -e "   SSL: ${YELLOW}${USE_SSL}${NC}"
    echo ""
    
    # Check web interface
    if curl -s http://localhost:8080/guacamole/ | grep -q "Guacamole" 2>/dev/null; then
        echo -e "${GREEN}✓ Web interface accessible${NC}"
    else
        echo -e "${YELLOW}⚠ Web interface not responding${NC}"
    fi
    
    echo ""
}

###########################################
# Restart All Services
###########################################

restart_services() {
    print_header
    echo -e "${CYAN}🔄 Restarting all Guacamole services...${NC}"
    echo ""
    
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}❌ Guacamole belum terinstal${NC}"
        return 1
    fi
    
    source "$ENV_FILE"
    
    log_info "Restarting PostgreSQL..."
    systemctl restart postgresql
    sleep 2
    
    log_info "Restarting guacd..."
    systemctl restart guacd
    sleep 2
    
    log_info "Restarting ${TOMCAT_VERSION}..."
    systemctl restart ${TOMCAT_VERSION}
    sleep 5
    
    log_info "Restarting nginx..."
    systemctl restart nginx
    sleep 2
    
    echo ""
    echo -e "${GREEN}✓ All services restarted${NC}"
    echo ""
    
    check_status
}

###########################################
# Main Menu
###########################################

show_menu() {
    while true; do
        print_header
        echo -e "${CYAN}Pilih opsi:${NC}"
        echo ""
        echo "  1) Install Guacamole (Full Installation)"
        echo "  2) Check Status"
        echo "  3) Restart All Services"
        echo "  4) Rollback (Remove Guacamole, keep packages)"
        echo "  5) Purge Complete (Remove everything)"
        echo "  6) View Logs"
        echo "  7) Exit"
        echo ""
        read -p "Masukkan pilihan [1-7]: " choice
        
        case $choice in
            1)
                install_guacamole
                read -p "Tekan Enter untuk kembali ke menu..."
                ;;
            2)
                check_status
                read -p "Tekan Enter untuk kembali ke menu..."
                ;;
            3)
                restart_services
                read -p "Tekan Enter untuk kembali ke menu..."
                ;;
            4)
                rollback_installation
                read -p "Tekan Enter untuk kembali ke menu..."
                ;;
            5)
                purge_guacamole
                read -p "Tekan Enter untuk kembali ke menu..."
                ;;
            6)
                echo ""
                echo -e "${CYAN}=== Last 30 lines of main log ===${NC}"
                tail -n 30 "$LOG_FILE" 2>/dev/null || echo "Log file not found"
                echo ""
                echo -e "${CYAN}=== Last 20 lines of debug log ===${NC}"
                tail -n 20 "$DEBUG_LOG_FILE" 2>/dev/null || echo "Debug log not found"
                echo ""
                read -p "Tekan Enter untuk kembali ke menu..."
                ;;
            7)
                echo ""
                echo -e "${GREEN}Terima kasih telah menggunakan Guacamole Installer!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid!${NC}"
                sleep 2
                ;;
        esac
    done
}

###########################################
# Main Execution
###########################################

main() {
    # Check root FIRST before doing anything
    check_root
    
    # Initialize log files (now we have root permission)
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "=== Guacamole Installer Log Started at $(date) ===" > "$LOG_FILE"
    echo "=== Guacamole Installer DEBUG Log Started at $(date) ===" > "$DEBUG_LOG_FILE"
    
    # Set proper permissions
    chmod 644 "$LOG_FILE" "$DEBUG_LOG_FILE"
    
    # NOW set up debug trap (after we have permissions)
    trap 'log_command "$BASH_COMMAND"' DEBUG
    
    # Initialize installation flag
    INSTALL_IN_PROGRESS="false"
    
    # Check if error flag exists
    if [[ -f "$ERROR_FLAG" ]]; then
        echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║               ⚠️ DETEKSI INSTALASI GAGAL ⚠️              ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Instalasi sebelumnya gagal. Disarankan untuk:${NC}"
        echo -e "  1. Lihat log error dengan opsi menu 'View Logs'"
        echo -e "  2. Jalankan rollback terlebih dahulu"
        echo ""
        read -p "Tekan Enter untuk melanjutkan ke menu..."
    fi
    
    show_menu
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
