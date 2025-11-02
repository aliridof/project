#!/bin/bash

###########################################
# Apache Guacamole Auto Installer (Universal)
# Supports: Debian/Ubuntu & RHEL/CentOS/Fedora
# Version: 3.1.0 - Production Grade (Enhanced Logging)
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

# Guacamole versions - will be auto-detected
GUAC_VERSION=""
GUAC_SERVER_VERSION=""
POSTGRES_JDBC_VERSION="42.7.3"

###########################################
# Enhanced Logging Function
###########################################

# Log every command for debugging
log_command() {
    local cmd="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] EXECUTING: ${cmd}" >> "$DEBUG_LOG_FILE"
}

# Set up the debug trap
trap 'log_command "$BASH_COMMAND"' DEBUG

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
        echo -e "${RED}🔍 UNTUK MENCARI PENYEBAB ERROR:${NC}"
        echo -e "   1. Lihat log utama untuk pesan error terakhir:"
        echo -e "      ${YELLOW}tail -n 20 ${LOG_FILE}${NC}"
        echo ""
        echo -e "   2. Lihat log debug untuk perintah yang GAGAL (baris terakhir):"
        echo -e "      ${YELLOW}tail -n 5 ${DEBUG_LOG_FILE}${NC}"
        echo ""
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
    echo "║     Apache Guacamole Auto Installer v3.1.0            ║"
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

# ... (Fungsi check_system_requirements, get_public_ip, validate_domain, check_dns_propagation, detect_guacamole_version, detect_tomcat_version, show_menu tidak berubah) ...
# Salin dari versi sebelumnya

###########################################
# Installation Functions
###########################################

gather_user_input() {
    # ... (Fungsi ini tidak berubah) ...
    log_info "Mengumpulkan informasi konfigurasi..."
    # ... (isi fungsi sama seperti sebelumnya) ...
}

create_backup() {
    # ... (Fungsi ini tidak berubah) ...
    log_info "Membuat backup state sebelum instalasi..."
    # ... (isi fungsi sama seperti sebelumnya) ...
}

install_dependencies() {
    log "Memperbarui sistem dan menginstal dependensi..."
    export DEBIAN_FRONTEND=noninteractive
    
    log_info "Menjalankan perintah update paket: ${PKG_UPDATE_CMD}"
    eval "$PKG_UPDATE_CMD" >> "$LOG_FILE" 2>&1
    
    source "$ENV_FILE"
    
    log_info "Menginstal paket-paket dependensi..."
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        log_info "Menginstal paket untuk sistem berbasis APT..."
        $PKG_INSTALL_CMD \
            build-essential libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin \
            libossp-uuid-dev libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
            freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev \
            libwebsockets-dev libpulse-dev libssl-dev libvorbis-dev libwebp-dev wget curl git \
            nginx postgresql postgresql-contrib openjdk-17-jdk ${TOMCAT_VERSION} ${TOMCAT_VERSION}-admin \
            certbot python3-certbot-nginx net-tools dnsutils iputils-ping \
            >> "$LOG_FILE" 2>&1
    else # dnf/yum
        log_info "Menginstal paket epel-release untuk sistem berbasis DNF/YUM..."
        $PKG_INSTALL_CMD epel-release -y >> "$LOG_FILE" 2>&1
        log_info "Menginstal grup paket 'Development Tools'..."
        $PKG_INSTALL_CMD @development-tools -y >> "$LOG_FILE" 2>&1
        log_info "Menginstal paket-paket dependensi lainnya..."
        $PKG_INSTALL_CMD \
            cairo-devel libjpeg-turbo-devel libpng-devel libtool-devel uuid-devel \
            libavcodec-devel libavformat-devel libavutil-devel libswscale-devel \
            freerdp-devel pango-devel libssh2-devel libtelnet-devel libvncserver-devel \
            libwebsockets-devel pulseaudio-libs-devel openssl-devel libvorbis-devel libwebp-devel \
            wget curl git nginx postgresql-server postgresql-contrib java-17-openjdk-devel \
            ${TOMCAT_VERSION} certbot python3-certbot-nginx net-tools bind-utils iputils \
            >> "$LOG_FILE" 2>&1
    fi
    
    log "✓ Dependensi berhasil diinstal"
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
        log_info "Melakukan konfigurasi PostgreSQL untuk sistem APT..."
        $SERVICE_CMD start postgresql
        $SERVICE_CMD enable postgresql
        wait_for_service postgresql || exit 1
        PG_VERSION=$(psql --version | grep -oP '(?<=PostgreSQL )[0-9]+' | head -n1)
        sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME};" >> "$LOG_FILE" 2>&1 || true
        sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" >> "$LOG_FILE" 2>&1 || true
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" >> "$LOG_FILE" 2>&1
    else # dnf/yum
        log_info "Melakukan inisialisasi database untuk sistem DNF/YUM..."
        postgresql-setup --initdb >> "$LOG_FILE" 2>&1
        $SERVICE_CMD start postgresql
        $SERVICE_CMD enable postgresql
        wait_for_service postgresql || exit 1
        log_info "Mengatur otentikasi PostgreSQL dan listen address..."
        sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' /var/lib/pgsql/data/pg_hba.conf
        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf
        $SERVICE_CMD restart postgresql
        wait_for_service postgresql || exit 1
        sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME};" >> "$LOG_FILE" 2>&1 || true
        sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" >> "$LOG_FILE" 2>&1 || true
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" >> "$LOG_FILE" 2>&1
    fi
    
    log "✓ PostgreSQL berhasil dikonfigurasi"
}

# ... (Fungsi install_guacamole_server, install_guacamole_client, configure_guacamole, setup_nginx, setup_ssl, setup_firewall, setup_logging, create_backup_script, verify_installation, print_installation_summary, install_guacamole, rollback_installation, purge_guacamole tidak berubah secara signifikan) ...
# Salin dari versi sebelumnya dan pastikan untuk menggunakan variabel $SERVICE_CMD, $PKG_MANAGER, dll.

###########################################
# Main Execution
###########################################

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Initialize log files
    echo "=== Guacamole Installer Log Started at $(date) ===" > "$LOG_FILE"
    echo "=== Guacamole Installer DEBUG Log Started at $(date) ===" > "$DEBUG_LOG_FILE"

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
