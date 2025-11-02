#!/bin/bash

###########################################
# Apache Guacamole Auto Installer
# Ubuntu 24.04 LTS Minimal x86_64
# Version: 2.0.1 - Production Grade (Fixed)
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

# Guacamole versions - will be auto-detected
GUAC_VERSION=""
GUAC_SERVER_VERSION=""
POSTGRES_JDBC_VERSION="42.7.3 # Fallback version if detection fails"

###########################################
# Error Handling & Cleanup
###########################################

cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
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
    echo "║     Apache Guacamole Auto Installer v2.0.1            ║"
    echo "║     Ubuntu 24.04 LTS x86_64 - Production Grade        ║"
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

check_ubuntu() {
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "Script ini hanya mendukung Ubuntu"
        exit 1
    fi
    
    local version=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    if [[ "$version" != "24.04" ]]; then
        log_warning "Script dirancang untuk Ubuntu 24.04, versi Anda: $version"
        read -p "Lanjutkan? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

###########################################
# Pre-flight Checks
###########################################

check_system_requirements() {
    log_info "Memeriksa system requirements..."
    
    local errors=0
    
    # Check disk space (minimal 10GB)
    local free_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=$((10 * 1024 * 1024)) # 10GB in KB
    
    if [[ $free_space -lt $required_space ]]; then
        log_error "Disk space tidak cukup. Minimal 10GB, tersedia: $((free_space / 1024 / 1024))GB"
        ((errors++))
    else
        log "✓ Disk space: $((free_space / 1024 / 1024))GB tersedia"
    fi
    
    # Check RAM (minimal 2GB)
    local total_mem=$(free -m | awk 'NR==2 {print $2}')
    if [[ $total_mem -lt 2000 ]]; then
        log_error "RAM tidak cukup. Minimal 2GB, tersedia: ${total_mem}MB"
        ((errors++))
    else
        log "✓ RAM: ${total_mem}MB tersedia"
    fi
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt 2 ]]; then
        log_warning "CPU cores kurang dari 2, performa mungkin tidak optimal"
    else
        log "✓ CPU cores: ${cpu_cores}"
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
    
    # Check if ports are available
    local ports=(80 443 8080 4822 5432)
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":${port} " || \
           ss -tuln 2>/dev/null | grep -q ":${port} "; then
            log_warning "Port $port sudah digunakan, mungkin ada konflik"
        fi
    done
    
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
    
    # Try to get latest version from Apache
    local latest_version=$(curl -s https://guacamole.apache.org/releases/ | \
        grep -oP '(?<=guacamole-server-)[0-9]+\.[0-9]+\.[0-9]+' | \
        sort -V | tail -n1)
    
    if [[ -z "$latest_version" ]]; then
        # Fallback to known stable version
        latest_version="1.5.5"
        log_warning "Auto-detect gagal, menggunakan version default: $latest_version"
    else
        log "✓ Guacamole version terdeteksi: $latest_version"
    fi
    
    GUAC_VERSION="$latest_version"
    GUAC_SERVER_VERSION="$latest_version"
}

detect_postgresql_version() {
    log_info "Mendeteksi PostgreSQL version..."
    
    # Get installed PostgreSQL version
    local pg_version=$(psql --version 2>/dev/null | grep -oP '(?<=PostgreSQL )[0-9]+' | head -n1)
    
    if [[ -z "$pg_version" ]]; then
        # Will be detected after installation
        log_info "PostgreSQL belum terinstall"
        echo ""
        return
    fi
    
    log "✓ PostgreSQL version: $pg_version"
    echo "$pg_version"
}

detect_tomcat_version() {
    log_info "Mendeteksi Tomcat version yang tersedia..."
    
    # Check available tomcat versions
    local available_versions=$(apt-cache search tomcat | grep -oP 'tomcat[0-9]+(?= )' | sort -V | tail -n1)
    
    if [[ -z "$available_versions" ]]; then
        log_error "Tidak menemukan Tomcat di repository"
        exit 1
    fi
    
    log "✓ Tomcat version tersedia: $available_versions"
    echo "$available_versions"
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
    log_info "Mengumpulkan informasi konfigurasi..."
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📝 KONFIGURASI INSTALASI${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    # Get domain or use IP
    PUBLIC_IP=$(get_public_ip) || exit 1
    echo -e "\n${GREEN}✓ IP Publik terdeteksi:${NC} ${YELLOW}${PUBLIC_IP}${NC}"
    echo ""
    echo -e "${BLUE}[Domain Configuration]${NC}"
    echo -e "Kosongkan untuk menggunakan IP (Self-signed SSL)"
    echo -e "Isi dengan domain untuk Let's Encrypt SSL (gratis & trusted)"
    read -p "Domain (contoh: guac.example.com): " DOMAIN
    
    if [[ -z "$DOMAIN" ]]; then
        DOMAIN="$PUBLIC_IP"
        USE_LETSENCRYPT=false
        echo -e "${YELLOW}→ Mode: IP Address dengan Self-signed SSL${NC}"
    else
        if validate_domain "$DOMAIN"; then
            USE_LETSENCRYPT=true
            echo -e "${GREEN}→ Mode: Domain dengan Let's Encrypt SSL${NC}"
            
            # Check DNS propagation
            if ! check_dns_propagation "$DOMAIN" "$PUBLIC_IP"; then
                log_warning "DNS belum pointing ke server ini!"
                echo -e "${YELLOW}Let's Encrypt akan gagal jika DNS belum propagate${NC}"
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
    # PostgreSQL password
    while true; do
        read -sp "Password PostgreSQL (min 12 karakter, mix huruf+angka+simbol): " DB_PASSWORD
        echo
        if [[ ${#DB_PASSWORD} -ge 12 ]] && [[ "$DB_PASSWORD" =~ [A-Z] ]] && \
           [[ "$DB_PASSWORD" =~ [a-z] ]] && [[ "$DB_PASSWORD" =~ [0-9] ]]; then
            read -sp "Konfirmasi password PostgreSQL: " DB_PASSWORD_CONFIRM
            echo
            if [[ "$DB_PASSWORD" == "$DB_PASSWORD_CONFIRM" ]]; then
                echo -e "${GREEN}✓ Password database valid${NC}"
                break
            else
                echo -e "${RED}✗ Password tidak cocok, coba lagi${NC}"
            fi
        else
            echo -e "${RED}✗ Password harus min 12 karakter dengan huruf besar, kecil, dan angka${NC}"
        fi
    done
    
    echo ""
    echo -e "${BLUE}[Guacamole Admin Configuration]${NC}"
    # Guacamole admin password
    while true; do
        read -sp "Password Guacamole Admin (min 12 karakter, mix huruf+angka+simbol): " GUAC_PASSWORD
        echo
        if [[ ${#GUAC_PASSWORD} -ge 12 ]] && [[ "$GUAC_PASSWORD" =~ [A-Z] ]] && \
           [[ "$GUAC_PASSWORD" =~ [a-z] ]] && [[ "$GUAC_PASSWORD" =~ [0-9] ]]; then
            read -sp "Konfirmasi password Guacamole Admin: " GUAC_PASSWORD_CONFIRM
            echo
            if [[ "$GUAC_PASSWORD" == "$GUAC_PASSWORD_CONFIRM" ]]; then
                echo -e "${GREEN}✓ Password admin valid${NC}"
                break
            else
                echo -e "${RED}✗ Password tidak cocok, coba lagi${NC}"
            fi
        else
            echo -e "${RED}✗ Password harus min 12 karakter dengan huruf besar, kecil, dan angka${NC}"
        fi
    done
    
    # Email for Let's Encrypt
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
    
    # Detect versions
    detect_guacamole_version
    TOMCAT_VERSION=$(detect_tomcat_version)
    
    # Save to env file
    mkdir -p "$INSTALL_DIR"
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    log_info "Membuat file environment..."
    
    cat > "$ENV_FILE" <<EOF
###########################################
# Guacamole Environment Configuration
# Auto-generated on $(date)
###########################################

# ========================================
# Domain & Network Configuration
# ========================================
DOMAIN=${DOMAIN}
PUBLIC_IP=${PUBLIC_IP}
USE_LETSENCRYPT=${USE_LETSENCRYPT}
LE_EMAIL=${LE_EMAIL:-}

# ========================================
# Database Configuration
# ========================================
DB_NAME=guacamole_db
DB_USER=guacamole_user
DB_PASSWORD=${DB_PASSWORD}
DB_HOST=localhost
DB_PORT=5432

# ========================================
# Guacamole Admin Configuration
# ========================================
GUAC_ADMIN_USER=guacadmin
GUAC_ADMIN_PASSWORD=${GUAC_PASSWORD}

# ========================================
# Version Configuration
# ========================================
GUAC_VERSION=${GUAC_VERSION}
GUAC_SERVER_VERSION=${GUAC_SERVER_VERSION}
TOMCAT_VERSION=${TOMCAT_VERSION}

# ========================================
# Installation Metadata
# ========================================
INSTALL_DATE=$(date +%Y-%m-%d_%H-%M-%S)
INSTALLER_VERSION=2.0.1
EOF
    
    chmod 600 "$ENV_FILE"
    echo -e "${GREEN}✓ Environment file dibuat: ${ENV_FILE}${NC}"
    
    # Also create .env.example as reference
    cp "$ENV_FILE" "${INSTALL_DIR}/.env.example"
    sed -i 's/DB_PASSWORD=.*/DB_PASSWORD=YourSecurePassword123!@#/g' "${INSTALL_DIR}/.env.example"
    sed -i 's/GUAC_ADMIN_PASSWORD=.*/GUAC_ADMIN_PASSWORD=YourAdminPassword123!@#/g' "${INSTALL_DIR}/.env.example"
    sed -i 's/LE_EMAIL=.*/LE_EMAIL=admin@your-domain.com/g' "${INSTALL_DIR}/.env.example"
    chmod 644 "${INSTALL_DIR}/.env.example"
    echo -e "${GREEN}✓ Template file dibuat: ${INSTALL_DIR}/.env.example${NC}"
    
    # Show configuration summary
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📋 RINGKASAN KONFIGURASI${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Domain/IP:${NC}           ${DOMAIN}"
    echo -e "${GREEN}SSL Type:${NC}            $([ "$USE_LETSENCRYPT" = true ] && echo "Let's Encrypt" || echo "Self-signed")"
    echo -e "${GREEN}Guacamole Ver:${NC}       ${GUAC_VERSION}"
    echo -e "${GREEN}Tomcat Ver:${NC}          ${TOMCAT_VERSION}"
    echo -e "${GREEN}Database:${NC}            guacamole_db"
    echo -e "${GREEN}DB User:${NC}             guacamole_user"
    echo -e "${GREEN}Admin User:${NC}          guacadmin"
    echo -e "${GREEN}Guacamole URL:${NC}       https://${DOMAIN}/guacamole/"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    read -p "Lanjutkan instalasi dengan konfigurasi di atas? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Instalasi dibatalkan oleh user"
        rm -f "$ENV_FILE" "${INSTALL_DIR}/.env.example"
        exit 0
    fi
    
    log "Konfigurasi dikonfirmasi, melanjutkan instalasi..."
}

create_backup() {
    log_info "Membuat backup state sebelum instalasi..."
    BACKUP_DIR="/root/guacamole-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing configs if any
    [[ -f /etc/nginx/sites-enabled/guacamole ]] && cp /etc/nginx/sites-enabled/guacamole "$BACKUP_DIR/" 2>/dev/null || true
    [[ -d /etc/guacamole ]] && cp -r /etc/guacamole "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup database if exists
    if sudo -u postgres psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw guacamole_db; then
        log_info "Backing up existing database..."
        sudo -u postgres pg_dump guacamole_db | gzip > "$BACKUP_DIR/guacamole_db_backup.sql.gz" 2>/dev/null || true
    fi
    
    # Save package list
    dpkg --get-selections > "$BACKUP_DIR/packages.list"
    
    echo "$BACKUP_DIR" > "${INSTALL_DIR}/.backup_location"
    log "Backup dibuat di: $BACKUP_DIR"
}

install_dependencies() {
    log "Memperbarui sistem dan menginstal dependensi..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Update package list
    apt-get update -y >> "$LOG_FILE" 2>&1
    
    # Upgrade existing packages
    apt-get upgrade -y >> "$LOG_FILE" 2>&1
    
    # Get Tomcat version from env
    source "$ENV_FILE"
    
    log_info "Installing Tomcat ${TOMCAT_VERSION}..."
    
    # Base dependencies
    apt-get install -y \
        build-essential \
        libcairo2-dev \
        libjpeg-turbo8-dev \
        libpng-dev \
        libtool-bin \
        libossp-uuid-dev \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libswscale-dev \
        freerdp2-dev \
        libpango1.0-dev \
        libssh2-1-dev \
        libtelnet-dev \
        libvncserver-dev \
        libwebsockets-dev \
        libpulse-dev \
        libssl-dev \
        libvorbis-dev \
        libwebp-dev \
        wget \
        curl \
        git \
        ufw \
        nginx \
        postgresql \
        postgresql-contrib \
        openjdk-17-jdk \
        ${TOMCAT_VERSION} \
        ${TOMCAT_VERSION}-admin \
        ${TOMCAT_VERSION}-common \
        ${TOMCAT_VERSION}-user \
        certbot \
        python3-certbot-nginx \
        netstat \
        net-tools \
        dnsutils \
        >> "$LOG_FILE" 2>&1
    
    log "Dependensi berhasil diinstal"
}

wait_for_service() {
    local service=$1
    local max_wait=${2:-30}
    local counter=0
    
    log_info "Menunggu $service siap..."
    
    while ! systemctl is-active --quiet "$service"; do
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
    
    # Start PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    wait_for_service postgresql || exit 1
    
    # Detect PostgreSQL version
    PG_VERSION=$(detect_postgresql_version)
    if [[ -z "$PG_VERSION" ]]; then
        PG_VERSION=$(psql --version | grep -oP '(?<=PostgreSQL )[0-9]+' | head -n1)
    fi
    
    log_info "PostgreSQL version: $PG_VERSION"
    
    # Create database with UTF8 encoding
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} WITH ENCODING 'UTF8' LC_COLLATE='en_US.UTF-8' LC_CTYPE='en_US.UTF-8';" >> "$LOG_FILE" 2>&1 || true
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" >> "$LOG_FILE" 2>&1 || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" >> "$LOG_FILE" 2>&1
    sudo -u postgres psql -c "ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};" >> "$LOG_FILE" 2>&1
    sudo -u postgres psql -d ${DB_NAME} -c "GRANT ALL ON SCHEMA public TO ${DB_USER};" >> "$LOG_FILE" 2>&1
    
    # Performance tuning based on system RAM
    local total_mem=$(free -m | awk 'NR==2 {print $2}')
    local shared_buffers=$((total_mem / 4))
    local effective_cache=$((total_mem * 3 / 4))
    
    cat >> "/etc/postgresql/${PG_VERSION}/main/postgresql.conf" <<EOF

# Guacamole Performance Tuning
max_connections = 100
shared_buffers = ${shared_buffers}MB
effective_cache_size = ${effective_cache}MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 2621kB
min_wal_size = 1GB
max_wal_size = 4GB
EOF
    
    systemctl restart postgresql
    wait_for_service postgresql || exit 1
    
    log "PostgreSQL berhasil dikonfigurasi"
}

install_guacamole_server() {
    log "Menginstal Guacamole Server (guacd)..."
    
    source "$ENV_FILE"
    
    cd /tmp
    
    # Download with retry
    local max_retries=3
    local retry=0
    while [[ $retry -lt $max_retries ]]; do
        if wget "https://downloads.apache.org/guacamole/${GUAC_SERVER_VERSION}/source/guacamole-server-${GUAC_SERVER_VERSION}.tar.gz" -O guacamole-server.tar.gz >> "$LOG_FILE" 2>&1; then
            break
        fi
        ((retry++))
        log_warning "Download gagal, retry $retry/$max_retries..."
        sleep 5
    done
    
    if [[ $retry -eq $max_retries ]]; then
        log_error "Gagal download guacamole-server setelah $max_retries percobaan"
        exit 1
    fi
    
    tar -xzf guacamole-server.tar.gz
    cd "guacamole-server-${GUAC_SERVER_VERSION}"
    
    ./configure --with-init-dir=/etc/init.d --enable-allow-freerdp-snapshots >> "$LOG_FILE" 2>&1
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
    
    systemctl daemon-reload
    systemctl start guacd
    systemctl enable guacd
    
    wait_for_service guacd || exit 1
    
    log "Guacamole Server berhasil diinstal"
}

install_guacamole_client() {
    log "Menginstal Guacamole Client..."
    
    source "$ENV_FILE"
    
    cd /tmp
    
    # Download client
    local max_retries=3
    local retry=0
    while [[ $retry -lt $max_retries ]]; do
        if wget "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war" -O guacamole.war >> "$LOG_FILE" 2>&1; then
            break
        fi
        ((retry++))
        log_warning "Download gagal, retry $retry/$max_retries..."
        sleep 5
    done
    
    mkdir -p /etc/guacamole/{extensions,lib}
    cp guacamole.war /etc/guacamole/
    
    # Detect Tomcat webapps directory
    TOMCAT_WEBAPPS="/var/lib/${TOMCAT_VERSION}/webapps"
    if [[ ! -d "$TOMCAT_WEBAPPS" ]]; then
        log_error "Tomcat webapps directory tidak ditemukan: $TOMCAT_WEBAPPS"
        exit 1
    fi
    
    ln -sf /etc/guacamole/guacamole.war "${TOMCAT_WEBAPPS}/guacamole.war"
    
    # Download PostgreSQL extension
    wget "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz" -O guacamole-auth-jdbc.tar.gz >> "$LOG_FILE" 2>&1
    tar -xzf guacamole-auth-jdbc.tar.gz
    cp "guacamole-auth-jdbc-${GUAC_VERSION}/postgresql/guacamole-auth-jdbc-postgresql-${GUAC_VERSION}.jar" /etc/guacamole/extensions/
    
    # Download PostgreSQL JDBC driver
    wget "https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar" -O /etc/guacamole/lib/postgresql-${POSTGRES_JDBC_VERSION}.jar >> "$LOG_FILE" 2>&1
    
    # Initialize database schema
    cat "guacamole-auth-jdbc-${GUAC_VERSION}/postgresql/schema/"*.sql | sudo -u postgres psql -d ${DB_NAME} >> "$LOG_FILE" 2>&1
    
    log "Guacamole Client berhasil diinstal"
}

configure_guacamole() {
    log "Mengkonfigurasi Guacamole..."
    
    source "$ENV_FILE"
    
    # Create guacamole.properties
    cat > /etc/guacamole/guacamole.properties <<EOF
# Hostname and port of guacamole proxy
guacd-hostname: localhost
guacd-port: 4822

# PostgreSQL properties
postgresql-hostname: ${DB_HOST}
postgresql-port: ${DB_PORT}
postgresql-database: ${DB_NAME}
postgresql-username: ${DB_USER}
postgresql-password: ${DB_PASSWORD}
postgresql-auto-create-accounts: true

# Additional settings
postgresql-default-max-connections: 10
postgresql-default-max-connections-per-user: 2

# Session timeout (in minutes)
session-timeout: 480
EOF
    
    # Create GUACAMOLE_HOME link
    ln -sf /etc/guacamole /usr/share/${TOMCAT_VERSION}/.guacamole 2>/dev/null || true
    
    # Set permissions
    chown -R ${TOMCAT_VERSION}:${TOMCAT_VERSION} /etc/guacamole
    
    # Update default admin password using proper hash
    log_info "Updating admin password dengan hash yang benar..."
    
    # Generate proper salted SHA-256 hash for Guacamole
    SALT=$(openssl rand -base64 32)
    PASSWORD_HASH=$(echo -n "${GUAC_ADMIN_PASSWORD}${SALT}" | openssl dgst -binary -sha256 | xxd -p -c 256)
    SALT_HEX=$(echo -n "${SALT}" | xxd -p -c 256)
    
    # Update using proper Guacamole format
    sudo -u postgres psql -d ${DB_NAME} << EOF >> "$LOG_FILE" 2>&1
UPDATE guacamole_entity 
SET name = '${GUAC_ADMIN_USER}' 
WHERE name = 'guacadmin';

UPDATE guacamole_user 
SET password_hash = decode('${PASSWORD_HASH}', 'hex'),
    password_salt = decode('${SALT_HEX}', 'hex'),
    password_date = CURRENT_TIMESTAMP 
WHERE entity_id = (SELECT entity_id FROM guacamole_entity WHERE name = '${GUAC_ADMIN_USER}');
EOF
    
    # Configure Tomcat for better performance
    TOMCAT_SERVICE="/lib/systemd/system/${TOMCAT_VERSION}.service"
    if [[ -f "$TOMCAT_SERVICE" ]]; then
        # Backup original
        cp "$TOMCAT_SERVICE" "${TOMCAT_SERVICE}.backup"
        
        # Add memory settings
        sed -i '/^\[Service\]/a Environment="CATALINA_OPTS=-Xms512m -Xmx2048m -XX:+UseG1GC"' "$TOMCAT_SERVICE"
        systemctl daemon-reload
    fi
    
    # Restart Tomcat
    systemctl restart ${TOMCAT_VERSION}
    systemctl enable ${TOMCAT_VERSION}
    
    wait_for_service ${TOMCAT_VERSION} 60 || exit 1
    
    # Wait for Guacamole to deploy
    log_info "Menunggu Guacamole deploy..."
    local counter=0
    while [[ ! -d "${TOMCAT_WEBAPPS}/guacamole" ]] && [[ $counter -lt 60 ]]; do
        sleep 1
        ((counter++))
    done
    
    if [[ -d "${TOMCAT_WEBAPPS}/guacamole" ]]; then
        log "✓ Guacamole deployed successfully"
    else
        log_warning "Guacamole deploy timeout, mungkin butuh waktu lebih"
    fi
    
    log "Guacamole berhasil dikonfigurasi"
}

setup_nginx() {
    log "Mengkonfigurasi Nginx..."
    
    source "$ENV_FILE"
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Create Nginx config
    cat > /etc/nginx/sites-available/guacamole <<'EOFNGINX'
# Guacamole Nginx Configuration
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER;
    
    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name DOMAIN_PLACEHOLDER;
    
    # SSL Configuration (will be updated)
    ssl_certificate /etc/ssl/certs/guacamole.crt;
    ssl_certificate_key /etc/ssl/private/guacamole.key;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Logging
    access_log /var/log/nginx/guacamole_access.log;
    error_log /var/log/nginx/guacamole_error.log;
    
    # Root redirect
    location / {
        return 301 https://$server_name/guacamole/;
    }
    
    # Guacamole location
    location /guacamole/ {
        proxy_pass http://localhost:8080/guacamole/;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_cookie_path /guacamole/ /guacamole/;
        access_log off;
        
        # Increase timeouts for long sessions
        proxy_connect_timeout 3600;
        proxy_send_timeout 3600;
        proxy_read_timeout 3600;
        send_timeout 3600;
        
        # Large file upload support
        client_max_body_size 4096m;
        client_body_timeout 3600;
    }
    
    # WebSocket specific location (if needed)
    location /guacamole/websocket-tunnel {
        proxy_pass http://localhost:8080/guacamole/websocket-tunnel;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        access_log off;
        
        # WebSocket timeouts
        proxy_connect_timeout 3600;
        proxy_send_timeout 3600;
        proxy_read_timeout 3600;
    }
    
    # Static assets caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
        proxy_pass http://localhost:8080;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
}
EOFNGINX
    
    # Replace domain placeholder
    sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g" /etc/nginx/sites-available/guacamole
    
    ln -sf /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/
    
    # Test nginx config
    if ! nginx -t >> "$LOG_FILE" 2>&1; then
        log_error "Nginx configuration test failed"
        exit 1
    fi
    
    log "Nginx berhasil dikonfigurasi"
}

setup_ssl() {
    log "Mengatur SSL certificate..."
    
    source "$ENV_FILE"
    
    if [[ "$USE_LETSENCRYPT" == true ]]; then
        log_info "Menggunakan Let's Encrypt untuk SSL..."
        
        # Stop nginx temporarily for certbot standalone
        systemctl stop nginx
        
        # Get certificate
        if certbot certonly --standalone -d "${DOMAIN}" --non-interactive --agree-tos -m "${LE_EMAIL}" >> "$LOG_FILE" 2>&1; then
            log "✓ Let's Encrypt certificate berhasil didapat"
            
            # Update nginx config to use Let's Encrypt certs
            sed -i "s|ssl_certificate /etc/ssl/certs/guacamole.crt;|ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;|g" /etc/nginx/sites-available/guacamole
            sed -i "s|ssl_certificate_key /etc/ssl/private/guacamole.key;|ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;|g" /etc/nginx/sites-available/guacamole
            
            # Setup auto-renewal
            systemctl enable certbot.timer
            systemctl start certbot.timer
            
            # Add renewal hook to reload nginx
            mkdir -p /etc/letsencrypt/renewal-hooks/deploy
            cat > /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh <<'EOF'
#!/bin/bash
systemctl reload nginx
EOF
            chmod +x /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh
        else
            log_error "Let's Encrypt gagal, falling back ke self-signed"
            USE_LETSENCRYPT=false
            sed -i "s/USE_LETSENCRYPT=true/USE_LETSENCRYPT=false/g" "$ENV_FILE"
        fi
        
        systemctl start nginx
    fi
    
    if [[ "$USE_LETSENCRYPT" == false ]]; then
        log_info "Menggunakan Self-signed certificate untuk SSL..."
        
        # Generate self-signed certificate
        mkdir -p /etc/ssl/private
        openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
            -keyout /etc/ssl/private/guacamole.key \
            -out /etc/ssl/certs/guacamole.crt \
            -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Guacamole/OU=IT/CN=${DOMAIN}" \
            >> "$LOG_FILE" 2>&1
        
        chmod 600 /etc/ssl/private/guacamole.key
        chmod 644 /etc/ssl/certs/guacamole.crt
        
        log "✓ Self-signed certificate berhasil dibuat"
    fi
    
    # Test and restart nginx
    nginx -t >> "$LOG_FILE" 2>&1
    systemctl restart nginx
    wait_for_service nginx || exit 1
}

setup_firewall() {
    log "Mengkonfigurasi UFW firewall..."
    
    # Reset UFW
    ufw --force reset >> "$LOG_FILE" 2>&1
    
    # Default policies
    ufw default deny incoming >> "$LOG_FILE" 2>&1
    ufw default allow outgoing >> "$LOG_FILE" 2>&1
    
    # Allow SSH (critical!)
    ufw allow 22/tcp comment 'SSH' >> "$LOG_FILE" 2>&1
    
    # Allow HTTP/HTTPS
    ufw allow 80/tcp comment 'HTTP' >> "$LOG_FILE" 2>&1
    ufw allow 443/tcp comment 'HTTPS' >> "$LOG_FILE" 2>&1
    
    # Enable UFW
    ufw --force enable >> "$LOG_FILE" 2>&1
    
    log "✓ UFW firewall berhasil dikonfigurasi"
}

setup_logging() {
    log "Mengkonfigurasi logging dan monitoring..."
    
    source "$ENV_FILE"
    
    # Create log directory
    mkdir -p /var/log/guacamole
    chown ${TOMCAT_VERSION}:${TOMCAT_VERSION} /var/log/guacamole
    
    # Logrotate for Guacamole
    cat > /etc/logrotate.d/guacamole <<EOF
/var/log/guacamole/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    maxsize 100M
    create 0640 ${TOMCAT_VERSION} ${TOMCAT_VERSION}
    sharedscripts
    postrotate
        systemctl reload ${TOMCAT_VERSION} > /dev/null 2>&1 || true
    endscript
}
EOF
    
    # Logrotate for Nginx
    cat > /etc/logrotate.d/nginx-guacamole <<EOF
/var/log/nginx/guacamole_*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    maxsize 100M
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 \$(cat /var/run/nginx.pid)
    endscript
}
EOF
    
    log "✓ Logging berhasil dikonfigurasi"
}

create_backup_script() {
    log "Membuat script backup database..."
    
    source "$ENV_FILE"
    
    cat > /usr/local/bin/backup-guacamole-db.sh <<EOFBACKUP
#!/bin/bash
# Guacamole Database Backup Script

BACKUP_DIR="/var/backups/guacamole"
DATE=\$(date +%Y%m%d-%H%M%S)
DB_NAME="${DB_NAME}"
MAX_BACKUPS=7

# Create backup directory
mkdir -p "\$BACKUP_DIR"

# Perform backup
echo "[\$(date)] Starting backup..."
if sudo -u postgres pg_dump "\$DB_NAME" | gzip > "\${BACKUP_DIR}/guacamole-db-\${DATE}.sql.gz"; then
    echo "[\$(date)] Backup completed: guacamole-db-\${DATE}.sql.gz"
    
    # Remove old backups
    find "\$BACKUP_DIR" -name "guacamole-db-*.sql.gz" -mtime +\$MAX_BACKUPS -delete
    echo "[\$(date)] Old backups cleaned (kept last \$MAX_BACKUPS days)"
else
    echo "[\$(date)] ERROR: Backup failed!" >&2
    exit 1
fi

# Show backup size
ls -lh "\${BACKUP_DIR}/guacamole-db-\${DATE}.sql.gz"
EOFBACKUP
    
    chmod +x /usr/local/bin/backup-guacamole-db.sh
    
    # Add cron job for daily backup at 2 AM
    (crontab -l 2>/dev/null | grep -v "backup-guacamole-db.sh"; echo "0 2 * * * /usr/local/bin/backup-guacamole-db.sh >> /var/log/guacamole-backup.log 2>&1") | crontab -
    
    # Create initial backup
    mkdir -p /var/backups/guacamole
    /usr/local/bin/backup-guacamole-db.sh >> /var/log/guacamole-backup.log 2>&1 || true
    
    log "✓ Backup script berhasil dibuat dan dijadwalkan"
}

verify_installation() {
    log "Melakukan verifikasi instalasi..."
    
    source "$ENV_FILE"
    
    local errors=0
    
    # Check services
    local services=("guacd" "${TOMCAT_VERSION}" "nginx" "postgresql")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "✓ Service $service: running"
        else
            log_error "✗ Service $service: not running"
            ((errors++))
        fi
    done
    
    # Check Guacamole deployment
    if [[ -d "/var/lib/${TOMCAT_VERSION}/webapps/guacamole" ]]; then
        log "✓ Guacamole WAR deployed"
    else
        log_error "✗ Guacamole WAR not deployed"
        ((errors++))
    fi
    
    # Check database connection
    if sudo -u postgres psql -d ${DB_NAME} -c "SELECT 1" >> "$LOG_FILE" 2>&1; then
        log "✓ Database connection: OK"
    else
        log_error "✗ Database connection: failed"
        ((errors++))
    fi
    
    # Check nginx config
    if nginx -t >> "$LOG_FILE" 2>&1; then
        log "✓ Nginx configuration: valid"
    else
        log_error "✗ Nginx configuration: invalid"
        ((errors++))
    fi
    
    # Check SSL certificate
    if [[ "$USE_LETSENCRYPT" == true ]]; then
        if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
            log "✓ SSL certificate: Let's Encrypt OK"
        else
            log_error "✗ SSL certificate: Let's Encrypt missing"
            ((errors++))
        fi
    else
        if [[ -f "/etc/ssl/certs/guacamole.crt" ]]; then
            log "✓ SSL certificate: Self-signed OK"
        else
            log_error "✗ SSL certificate: missing"
            ((errors++))
        fi
    fi
    
    # Test HTTP endpoint
    log_info "Testing HTTP endpoint..."
    sleep 5  # Give services time to fully start
    
    if curl -k -s -o /dev/null -w "%{http_code}" "https://localhost/guacamole/" | grep -q "200\|302"; then
        log "✓ HTTP endpoint: responding"
    else
        log_warning "⚠ HTTP endpoint: not responding yet (might need more time)"
    fi
    
    if [[ $errors -eq 0 ]]; then
        log "✓✓✓ Semua verifikasi passed!"
        return 0
    else
        log_error "Verifikasi gagal dengan $errors errors"
        return 1
    fi
}

print_installation_summary() {
    source "$ENV_FILE"
    
    clear
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║        ✓ INSTALASI GUACAMOLE BERHASIL DISELESAIKAN!          ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📋 INFORMASI AKSES${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    if [[ "$USE_LETSENCRYPT" == true ]]; then
        echo -e "${GREEN}🌐 URL Akses:${NC}        https://${DOMAIN}/guacamole/"
        echo -e "${GREEN}🔒 SSL Status:${NC}       Let's Encrypt (Trusted Certificate)"
    else
        echo -e "${GREEN}🌐 URL Akses:${NC}        https://${DOMAIN}/guacamole/"
        echo -e "${YELLOW}🔒 SSL Status:${NC}       Self-signed Certificate"
        echo -e "${YELLOW}   ⚠ Browser akan menampilkan security warning${NC}"
        echo -e "${YELLOW}   ⚠ Klik 'Advanced' → 'Proceed to site' untuk lanjut${NC}"
    fi
    
    echo -e "${GREEN}👤 Username:${NC}         ${GUAC_ADMIN_USER}"
    echo -e "${GREEN}🔑 Password:${NC}         ${GUAC_ADMIN_PASSWORD}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🗄️  INFORMASI DATABASE${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Database:${NC}            ${DB_NAME}"
    echo -e "${GREEN}DB User:${NC}             ${DB_USER}"
    echo -e "${GREEN}DB Password:${NC}         ${DB_PASSWORD}"
    echo -e "${GREEN}DB Host:${NC}             ${DB_HOST}:${DB_PORT}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📦 VERSI TERPASANG${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Guacamole:${NC}           ${GUAC_VERSION}"
    echo -e "${GREEN}Tomcat:${NC}              ${TOMCAT_VERSION}"
    echo -e "${GREEN}PostgreSQL:${NC}          $(detect_postgresql_version)"
    echo -e "${GREEN}Nginx:${NC}               $(nginx -v 2>&1 | cut -d'/' -f2)"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔧 PERINTAH BERGUNA${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Status Services:${NC}"
    echo -e "  systemctl status guacd"
    echo -e "  systemctl status ${TOMCAT_VERSION}"
    echo -e "  systemctl status nginx"
    echo -e "  systemctl status postgresql"
    echo ""
    echo -e "${GREEN}Restart Services:${NC}"
    echo -e "  systemctl restart guacd ${TOMCAT_VERSION} nginx"
    echo ""
    echo -e "${GREEN}Backup Database:${NC}"
    echo -e "  /usr/local/bin/backup-guacamole-db.sh"
    echo ""
    echo -e "${GREEN}View Logs:${NC}"
    echo -e "  tail -f ${LOG_FILE}"
    echo -e "  tail -f /var/log/nginx/guacamole_error.log"
    echo -e "  journalctl -u guacd -f"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📁 FILE KONFIGURASI${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Environment:${NC}         ${ENV_FILE}"
    echo -e "${GREEN}Guacamole:${NC}           /etc/guacamole/guacamole.properties"
    echo -e "${GREEN}Nginx:${NC}               /etc/nginx/sites-available/guacamole"
    echo -e "${GREEN}Backup Location:${NC}     /var/backups/guacamole/"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✨ Instalasi selesai pada: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}💡 CATATAN PENTING:${NC}"
    echo -e "   ${GREEN}✓${NC} Simpan informasi login ini dengan aman"
    echo -e "   ${GREEN}✓${NC} GANTI PASSWORD setelah login pertama kali"
    echo -e "   ${GREEN}✓${NC} Backup otomatis berjalan setiap hari jam 2 pagi"
    echo -e "   ${GREEN}✓${NC} Firewall (UFW) sudah dikonfigurasi"
    echo -e "   ${GREEN}✓${NC} Jalankan script ini untuk menu rollback/purge"
    echo ""
    
    # Save summary to file
    cat > "${INSTALL_DIR}/installation-summary.txt" <<EOF
═══════════════════════════════════════════════════════════════
GUACAMOLE INSTALLATION SUMMARY
═══════════════════════════════════════════════════════════════

Installation Date: $(date '+%Y-%m-%d %H:%M:%S')
Installer Version: 2.0.1

ACCESS INFORMATION
------------------
URL: https://${DOMAIN}/guacamole/
Username: ${GUAC_ADMIN_USER}
Password: ${GUAC_ADMIN_PASSWORD}
SSL Type: $([ "$USE_LETSENCRYPT" = true ] && echo "Let's Encrypt" || echo "Self-signed")

DATABASE INFORMATION
--------------------
Database: ${DB_NAME}
DB User: ${DB_USER}
DB Password: ${DB_PASSWORD}
DB Host: ${DB_HOST}:${DB_PORT}

INSTALLED VERSIONS
------------------
Guacamole: ${GUAC_VERSION}
Tomcat: ${TOMCAT_VERSION}
PostgreSQL: $(detect_postgresql_version)
Nginx: $(nginx -v 2>&1 | cut -d'/' -f2)

CONFIGURATION FILES
-------------------
Environment: ${ENV_FILE}
Guacamole: /etc/guacamole/guacamole.properties
Nginx: /etc/nginx/sites-available/guacamole
Backup Location: /var/backups/guacamole/

USEFUL COMMANDS
---------------
Services Status:
  systemctl status guacd ${TOMCAT_VERSION} nginx postgresql

Restart Services:
  systemctl restart guacd ${TOMCAT_VERSION} nginx

Backup Database:
  /usr/local/bin/backup-guacamole-db.sh

View Logs:
  tail -f ${LOG_FILE}
  tail -f /var/log/nginx/guacamole_error.log
  journalctl -u guacd -f

IMPORTANT NOTES
---------------
• Change default password after first login
• Automatic backup runs daily at 2 AM
• Firewall (UFW) is configured and enabled
• Run this script again for rollback/purge options

═══════════════════════════════════════════════════════════════
EOF
    
    chmod 600 "${INSTALL_DIR}/installation-summary.txt"
    echo -e "${GREEN}📄 Installation summary saved to:${NC}"
    echo -e "   ${INSTALL_DIR}/installation-summary.txt"
    echo ""
}

install_guacamole() {
    check_root
    check_ubuntu
    check_system_requirements
    gather_user_input
    create_backup
    install_dependencies
    setup_postgresql
    install_guacamole_server
    install_guacamole_client
    configure_guacamole
    setup_nginx
    setup_ssl
    setup_firewall
    setup_logging
    create_backup_script
    
    if verify_installation; then
        print_installation_summary
        # Remove error flag on success
        rm -f "$ERROR_FLAG"
    else
        log_error "Verifikasi instalasi gagal. Silakan cek log: ${LOG_FILE}"
        exit 1
    fi
}

###########################################
# Rollback Function
###########################################

rollback_installation() {
    clear
    print_header
    echo -e "${YELLOW}⚠️  ROLLBACK INSTALLATION${NC}"
    echo ""
    
    if [[ ! -f "${INSTALL_DIR}/.backup_location" ]]; then
        log_error "Backup location tidak ditemukan. Rollback tidak tersedia."
        echo ""
        read -p "Tekan Enter untuk kembali ke menu..."
        show_menu
        return
    fi
    
    BACKUP_DIR=$(cat "${INSTALL_DIR}/.backup_location")
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_error "Backup directory tidak ditemukan: $BACKUP_DIR"
        echo ""
        read -p "Tekan Enter untuk kembali ke menu..."
        show_menu
        return
    fi
    
    echo -e "${RED}PERINGATAN: Ini akan mengembalikan sistem ke kondisi sebelum instalasi.${NC}"
    echo -e "Backup location: ${BACKUP_DIR}"
    echo ""
    echo -e "Yang akan di-restore:"
    echo -e "  • Konfigurasi Nginx"
    echo -e "  • Konfigurasi Guacamole"
    echo -e "  • Database (jika ada backup)"
    echo ""
    read -p "Lanjutkan rollback? (ketik YES): " CONFIRM
    
    if [[ "$CONFIRM" != "YES" ]]; then
        log_info "Rollback dibatalkan"
        show_menu
        return
    fi
    
    log "Memulai rollback..."
    
    source "$ENV_FILE" 2>/dev/null || true
    
    # Stop services
    log_info "Menghentikan services..."
    systemctl stop ${TOMCAT_VERSION:-tomcat9} 2>/dev/null || true
    systemctl stop guacd 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    
    # Restore configs
    if [[ -d "$BACKUP_DIR" ]]; then
        log_info "Restoring configurations..."
        
        [[ -f "${BACKUP_DIR}/guacamole" ]] && cp "${BACKUP_DIR}/guacamole" /etc/nginx/sites-available/ 2>/dev/null || true
        [[ -d "${BACKUP_DIR}/guacamole" ]] && cp -r "${BACKUP_DIR}/guacamole"/* /etc/guacamole/ 2>/dev/null || true
        
        # Restore database if backup exists
        if [[ -f "${BACKUP_DIR}/guacamole_db_backup.sql.gz" ]]; then
            log_info "Restoring database..."
            gunzip < "${BACKUP_DIR}/guacamole_db_backup.sql.gz" | sudo -u postgres psql ${DB_NAME:-guacamole_db} 2>/dev/null || true
        fi
    fi
    
    # Restart services
    systemctl start postgresql 2>/dev/null || true
    systemctl start nginx 2>/dev/null || true
    
    log "✓ Rollback selesai"
    echo ""
    read -p "Tekan Enter untuk kembali ke menu..."
    show_menu
}

###########################################
# Purge Function
###########################################

purge_guacamole() {
    clear
    print_header
    echo -e "${RED}💀 PURGE GUACAMOLE (COMPLETE REMOVAL)${NC}"
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                     ⚠️  PERINGATAN KRITIS  ⚠️                  ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Operasi ini akan menghapus SEMUA komponen Guacamole:${NC}"
    echo ""
    echo -e "  ${RED}✗${NC} Guacamole Server & Client"
    echo -e "  ${RED}✗${NC} Database PostgreSQL (${DB_NAME:-guacamole_db})"
    echo -e "  ${RED}✗${NC} Konfigurasi Nginx"
    echo -e "  ${RED}✗${NC} SSL Certificates (self-signed)"
    echo -e "  ${RED}✗${NC} File environment dan logs"
    echo -e "  ${RED}✗${NC} Backup scripts dan cron jobs"
    echo -e "  ${RED}✗${NC} Semua data koneksi dan settings"
    echo ""
    echo -e "${GREEN}Packages sistem (PostgreSQL, Nginx, Tomcat) TETAP terinstall${NC}"
    echo ""
    echo -e "${RED}TIDAK ADA UNDO UNTUK OPERASI INI!${NC}"
    echo ""
    read -p "Ketik 'DELETE EVERYTHING' untuk konfirmasi: " CONFIRM
    
    if [[ "$CONFIRM" != "DELETE EVERYTHING" ]]; then
        log_info "Purge dibatalkan"
        show_menu
        return
    fi
    
    log "Memulai purge Guacamole..."
    
    # Load env if exists
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE"
    else
        # Set defaults if env not found
        DB_NAME="guacamole_db"
        DB_USER="guacamole_user"
        TOMCAT_VERSION="tomcat9"
        DOMAIN=""
        USE_LETSENCRYPT=false
    fi
    
    # Stop services
    log_info "Menghentikan services..."
    systemctl stop guacd 2>/dev/null || true
    systemctl stop ${TOMCAT_VERSION} 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    systemctl disable guacd 2>/dev/null || true
    
    # Remove Guacamole server
    log_info "Menghapus Guacamole Server..."
    rm -rf /usr/local/sbin/guacd
    rm -rf /usr/local/lib/libguac*
    rm -rf /usr/local/include/guacamole
    rm -f /etc/systemd/system/guacd.service
    systemctl daemon-reload
    
    # Remove Guacamole client
    log_info "Menghapus Guacamole Client..."
    rm -rf /etc/guacamole
    rm -f /var/lib/${TOMCAT_VERSION}/webapps/guacamole.war
    rm -rf /var/lib/${TOMCAT_VERSION}/webapps/guacamole/
    rm -rf /usr/share/${TOMCAT_VERSION}/.guacamole
    
    # Remove database
    log_info "Menghapus database..."
    if sudo -u postgres psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "${DB_NAME}"; then
        sudo -u postgres psql -c "DROP DATABASE ${DB_NAME};" >> "$LOG_FILE" 2>&1
    fi
    if sudo -u postgres psql -t -c "\du" 2>/dev/null | cut -d \| -f 1 | grep -qw "${DB_USER}"; then
        sudo -u postgres psql -c "DROP USER ${DB_USER};" >> "$LOG_FILE" 2>&1
    fi
    
    # Remove Nginx config
    log_info "Menghapus konfigurasi Nginx..."
    rm -f /etc/nginx/sites-enabled/guacamole
    rm -f /etc/nginx/sites-available/guacamole
    systemctl reload nginx 2>/dev/null || true
    
    # Remove SSL certificates (self-signed only)
    if [[ "$USE_LETSENCRYPT" == false ]] && [[ -n "${DOMAIN}" ]]; then
        log_info "Menghapus self-signed SSL certificate..."
        rm -f /etc/ssl/certs/guacamole.crt
        rm -f /etc/ssl/private/guacamole.key
    fi
    
    # Remove backup script and cron job
    log_info "Menghapus backup script dan cron job..."
    rm -f /usr/local/bin/backup-guacamole-db.sh
    (crontab -l 2>/dev/null | grep -v "backup-guacamole-db.sh") | crontab -
    
    # Remove installation directory
    log_info "Menghapus direktori instalasi..."
    rm -rf "${INSTALL_DIR}"
    
    # Remove logrotate configs
    rm -f /etc/logrotate.d/guacamole
    rm -f /etc/logrotate.d/nginx-guacamole
    
    # Remove logs
    rm -rf /var/log/guacamole
    
    log "✓ Purge Guacamole selesai"
    echo ""
    echo -e "${GREEN}Semua komponen Guacamole telah dihapus.${NC}"
    echo -e "${YELLOW}Packages sistem (PostgreSQL, Nginx, Tomcat) tetap terinstall.${NC}"
    echo ""
    read -p "Tekan Enter untuk kembali ke menu..."
    show_menu
}

###########################################
# Main Execution
###########################################

# Main execution block
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check for error flag from previous failed run
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
