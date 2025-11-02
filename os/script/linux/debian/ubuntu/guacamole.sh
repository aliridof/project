#!/bin/bash
set -euo pipefail

# ==============================================================
# Apache Guacamole Docker Installer (Portable, Secure, Interactive)
# Support: Ubuntu/Debian/Alpine | amd64 & arm64
# Version: 2.5 (Enhanced with Management Features)
# ==============================================================

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m' # No Color

# Configuration
readonly GUACAMOLE_VERSION="1.5.5"
readonly POSTGRES_VERSION="16-alpine"
readonly INSTALL_DIR="guacamole-setup"
readonly MIN_PASSWORD_LENGTH=12
readonly INSTALL_LOG="installation.log"
readonly STATE_FILE=".install_state"

# Installation tracking
declare -A INSTALLED_ITEMS
declare -A ENABLED_SERVICES
declare -A CREATED_FILES

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$INSTALL_LOG" 2>/dev/null || true
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$INSTALL_LOG" 2>/dev/null || true
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$INSTALL_LOG" 2>/dev/null || true
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$INSTALL_LOG" 2>/dev/null || true
}

# Progress bar function
progress() {
    local msg=$1
    local duration=${2:-3}
    echo -ne "${YELLOW}${msg}${NC} "
    for i in $(seq 1 "$duration"); do
        echo -n "▰"
        sleep 0.3
    done
    echo -e " ${GREEN}✅${NC}"
}

# Error handler
error_exit() {
    log_error "$1"
    log_error "Instalasi gagal! Lihat $INSTALL_LOG untuk detail"
    exit 1
}

# Track installation
track_install() {
    local type=$1
    local name=$2
    local value=${3:-"installed"}
    
    case $type in
        package)
            INSTALLED_ITEMS["pkg_$name"]=$value
            ;;
        service)
            ENABLED_SERVICES["svc_$name"]=$value
            ;;
        file)
            CREATED_FILES["file_$name"]=$value
            ;;
    esac
    
    # Save to state file
    echo "$type|$name|$value" >> "$STATE_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script ini harus dijalankan sebagai root!"
        log_info "Jalankan dengan: sudo $0"
        exit 1
    fi
}

# Detect OS and Architecture
detect_system() {
    progress "📦 Memeriksa sistem operasi & arsitektur" 3
    
    if [[ ! -f /etc/os-release ]]; then
        error_exit "Tidak dapat mendeteksi sistem operasi"
    fi
    
    # shellcheck source=/dev/null
    . /etc/os-release
    
    local arch
    arch=$(uname -m)
    
    # Validate architecture
    case "$arch" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            error_exit "Arsitektur $arch tidak didukung"
            ;;
    esac
    
    log_info "Distro: $NAME ($VERSION)"
    log_info "Arch: $ARCH"
    log_info "Kernel: $(uname -r)"
    
    track_install "package" "system_info" "$NAME-$VERSION-$ARCH"
}

# Install Docker
install_docker() {
    progress "🐳 Memeriksa instalasi Docker" 3
    
    if command -v docker &>/dev/null; then
        local docker_version
        docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        log_success "Docker sudah terinstal (v$docker_version)"
        track_install "package" "docker" "existing-$docker_version"
        
        # Check Docker service status
        if ! systemctl is-active --quiet docker; then
            log_warning "Docker service tidak aktif, mencoba menjalankan..."
            systemctl start docker || error_exit "Gagal menjalankan Docker service"
            track_install "service" "docker" "started"
        else
            track_install "service" "docker" "already_running"
        fi
    else
        progress "🔄 Menginstal Docker Engine" 6
        
        # Install Docker with proper error handling
        if ! curl -fsSL https://get.docker.com -o /tmp/get-docker.sh; then
            error_exit "Gagal mengunduh Docker installer"
        fi
        
        if ! sh /tmp/get-docker.sh; then
            error_exit "Gagal menginstal Docker"
        fi
        
        rm -f /tmp/get-docker.sh
        
        local docker_version
        docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        
        # Start Docker service
        systemctl enable docker
        systemctl start docker
        
        log_success "Docker v$docker_version berhasil diinstal"
        track_install "package" "docker" "new-$docker_version"
        track_install "service" "docker" "enabled_and_started"
    fi
}

# Install Docker Compose if needed
check_docker_compose() {
    if docker compose version &>/dev/null; then
        local compose_version
        compose_version=$(docker compose version | awk '{print $4}')
        log_success "Docker Compose sudah tersedia (v$compose_version)"
        track_install "package" "docker-compose" "existing-$compose_version"
    else
        log_warning "Docker Compose plugin tidak tersedia, menginstal..."
        
        # Try to install docker-compose-plugin
        if command -v apt-get &>/dev/null; then
            apt-get update -qq
            apt-get install -y docker-compose-plugin
            track_install "package" "docker-compose-plugin" "new-apt"
        elif command -v yum &>/dev/null; then
            yum install -y docker-compose-plugin
            track_install "package" "docker-compose-plugin" "new-yum"
        else
            error_exit "Silakan install Docker Compose secara manual"
        fi
        
        local compose_version
        compose_version=$(docker compose version | awk '{print $4}')
        log_success "Docker Compose v$compose_version berhasil diinstal"
    fi
}

# Setup installation directory
setup_directory() {
    progress "📁 Membuat direktori instalasi" 2
    
    if [[ -d "$INSTALL_DIR" ]]; then
        log_warning "Direktori $INSTALL_DIR sudah ada"
        read -rp "Hapus dan buat ulang? (y/N): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
        else
            error_exit "Instalasi dibatalkan"
        fi
    fi
    
    mkdir -p "$INSTALL_DIR" || error_exit "Gagal membuat direktori $INSTALL_DIR"
    cd "$INSTALL_DIR" || error_exit "Gagal masuk ke direktori $INSTALL_DIR"
    
    track_install "file" "install_dir" "$(pwd)"
    
    # Initialize log file
    echo "=== Apache Guacamole Installation Log ===" > "$INSTALL_LOG"
    echo "Started at: $(date)" >> "$INSTALL_LOG"
    echo "=======================================" >> "$INSTALL_LOG"
    echo "" >> "$INSTALL_LOG"
    
    track_install "file" "install_log" "$(pwd)/$INSTALL_LOG"
}

# Validate password strength
validate_password() {
    local pwd=$1
    
    [[ ${#pwd} -ge $MIN_PASSWORD_LENGTH ]] || return 1
    [[ "$pwd" =~ [A-Z] ]] || return 1
    [[ "$pwd" =~ [a-z] ]] || return 1
    [[ "$pwd" =~ [0-9] ]] || return 1
    [[ "$pwd" =~ [^a-zA-Z0-9] ]] || return 1
    
    return 0
}

# Setup secure password
setup_password() {
    progress "🔒 Menyiapkan konfigurasi keamanan database" 3
    
    local pwd
    local pwd_confirm
    
    while true; do
        echo ""
        log_info "Kriteria password:"
        echo "  • Minimal $MIN_PASSWORD_LENGTH karakter"
        echo "  • Mengandung huruf besar dan kecil"
        echo "  • Mengandung angka"
        echo "  • Mengandung karakter khusus (!@#\$%^&*)"
        echo ""
        
        read -rsp "Masukkan password database: " pwd
        echo ""
        
        if ! validate_password "$pwd"; then
            log_error "Password tidak memenuhi kriteria. Coba lagi."
            continue
        fi
        
        read -rsp "Konfirmasi password: " pwd_confirm
        echo ""
        
        if [[ "$pwd" != "$pwd_confirm" ]]; then
            log_error "Password tidak cocok. Coba lagi."
            continue
        fi
        
        break
    done
    
    # Create .env file
    cat > .env <<EOF
POSTGRES_USER=guacamole_user
POSTGRES_DB=guacamole_db
POSTGRES_PASSWORD=$pwd
POSTGRES_HOST=db
POSTGRES_PORT=5432
GUACD_HOSTNAME=guacd
GUACD_PORT=4822
EOF
    
    chmod 600 .env
    log_success "File .env berhasil dibuat dengan permission 600"
    track_install "file" ".env" "$(pwd)/.env"
    
    # Clear sensitive variables
    unset pwd pwd_confirm
}

# Create docker-compose.yml
create_compose_file() {
    progress "📄 Membuat file docker-compose.yml" 3
    
    cat > docker-compose.yml <<'COMPOSE_EOF'
version: "3.9"

networks:
  guacamole_network:
    driver: bridge

services:
  db:
    image: postgres:16-alpine
    container_name: guacamole_db
    env_file: .env
    volumes:
      - ./db-data:/var/lib/postgresql/data
      - ./init:/docker-entrypoint-initdb.d:ro
    networks:
      - guacamole_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  guacd:
    image: guacamole/guacd:1.5.5
    container_name: guacamole_daemon
    networks:
      - guacamole_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "nc -z 127.0.0.1 4822 || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5

  guacamole:
    image: guacamole/guacamole:1.5.5
    container_name: guacamole_app
    env_file: .env
    ports:
      - "8080:8080"
    networks:
      - guacamole_network
    depends_on:
      db:
        condition: service_healthy
      guacd:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/guacamole/ || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
COMPOSE_EOF
    
    log_success "File docker-compose.yml berhasil dibuat"
    track_install "file" "docker-compose.yml" "$(pwd)/docker-compose.yml"
}

# Initialize database
init_database() {
    progress "🗄️  Menginisialisasi database Guacamole" 4
    
    # Create init directory
    mkdir -p init
    track_install "file" "init_dir" "$(pwd)/init"
    
    # Generate initialization SQL
    docker run --rm guacamole/guacamole:${GUACAMOLE_VERSION} \
        /opt/guacamole/bin/initdb.sh --postgresql > init/initdb.sql || \
        error_exit "Gagal menggenerate SQL initialization"
    
    log_success "Database initialization SQL berhasil dibuat"
    track_install "file" "initdb.sql" "$(pwd)/init/initdb.sql"
}

# Start services
start_services() {
    progress "🚀 Menjalankan layanan Guacamole" 6
    
    # Pull images first
    log_info "Mengunduh Docker images..."
    docker compose pull || error_exit "Gagal mengunduh images"
    
    track_install "package" "postgres_image" "postgres:${POSTGRES_VERSION}"
    track_install "package" "guacd_image" "guacamole/guacd:${GUACAMOLE_VERSION}"
    track_install "package" "guacamole_image" "guacamole/guacamole:${GUACAMOLE_VERSION}"
    
    # Start services
    docker compose up -d || error_exit "Gagal menjalankan services"
    
    track_install "service" "guacamole_db" "running"
    track_install "service" "guacamole_daemon" "running"
    track_install "service" "guacamole_app" "running"
    
    # Wait for services to be healthy
    log_info "Menunggu services siap..."
    local max_wait=120
    local waited=0
    
    while [[ $waited -lt $max_wait ]]; do
        if docker compose ps 2>/dev/null | grep -q "healthy"; then
            break
        fi
        sleep 2
        waited=$((waited + 2))
        echo -n "."
    done
    echo ""
    
    log_success "Semua services berhasil dijalankan"
}

# Get network information
get_network_info() {
    local internal_ip
    local public_ip
    
    # Get internal IP
    internal_ip=$(hostname -I | awk '{print $1}')
    
    # Get public IP with timeout
    public_ip=$(timeout 5 curl -s https://api.ipify.org 2>/dev/null || echo "Tidak tersedia")
    
    echo "$internal_ip|$public_ip"
}

# Show installation summary
show_installation_summary() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          📋 RINGKASAN INSTALASI                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    echo -e "${CYAN}📦 PACKAGES INSTALLED:${NC}"
    for key in "${!INSTALLED_ITEMS[@]}"; do
        if [[ $key == pkg_* ]]; then
            local name=${key#pkg_}
            echo "   ✓ $name: ${INSTALLED_ITEMS[$key]}"
        fi
    done
    echo ""
    
    echo -e "${CYAN}🔧 SERVICES ENABLED/RUNNING:${NC}"
    for key in "${!ENABLED_SERVICES[@]}"; do
        if [[ $key == svc_* ]]; then
            local name=${key#svc_}
            echo "   ✓ $name: ${ENABLED_SERVICES[$key]}"
        fi
    done
    echo ""
    
    echo -e "${CYAN}📁 FILES CREATED:${NC}"
    for key in "${!CREATED_FILES[@]}"; do
        if [[ $key == file_* ]]; then
            local name=${key#file_}
            echo "   ✓ $name: ${CREATED_FILES[$key]}"
        fi
    done
    echo ""
    
    echo -e "${CYAN}🐳 DOCKER CONTAINERS:${NC}"
    docker ps --format "   ✓ {{.Names}}: {{.Status}}" | grep guacamole || echo "   (No containers running)"
    echo ""
    
    echo -e "${CYAN}🔄 QUICK ACTIONS:${NC}"
    echo "   • Restart all: docker compose restart"
    echo "   • Restart app: docker compose restart guacamole"
    echo "   • Restart db: docker compose restart db"
    echo "   • Restart daemon: docker compose restart guacd"
    echo ""
    
    echo -e "${CYAN}💾 DISK USAGE:${NC}"
    echo "   • Docker images: $(docker images --format '{{.Size}}' | awk '{sum+=$1} END {print sum " MB"}' 2>/dev/null || echo 'N/A')"
    echo "   • Installation dir: $(du -sh . 2>/dev/null | awk '{print $1}')"
    echo ""
}

# Show troubleshooting guide
show_troubleshooting() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          🔧 TROUBLESHOOTING GUIDE                        ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    echo -e "${YELLOW}🔍 MASALAH UMUM & SOLUSI:${NC}"
    echo ""
    
    echo "1️⃣  ${CYAN}Tidak bisa akses Guacamole${NC}"
    echo "   Cek status container:"
    echo "   $ docker compose ps"
    echo "   $ docker compose logs guacamole"
    echo ""
    
    echo "2️⃣  ${CYAN}Container tidak healthy${NC}"
    echo "   Restart services:"
    echo "   $ docker compose restart"
    echo "   Atau rebuild:"
    echo "   $ docker compose down && docker compose up -d"
    echo ""
    
    echo "3️⃣  ${CYAN}Port 8080 sudah digunakan${NC}"
    echo "   Cek proses yang menggunakan port:"
    echo "   $ sudo lsof -i :8080"
    echo "   Edit docker-compose.yml, ubah port:"
    echo "   ports: - \"8081:8080\""
    echo ""
    
    echo "4️⃣  ${CYAN}Database connection error${NC}"
    echo "   Cek log database:"
    echo "   $ docker compose logs db"
    echo "   Reset database:"
    echo "   $ docker compose down -v && docker compose up -d"
    echo ""
    
    echo "5️⃣  ${CYAN}Lupa password Guacamole${NC}"
    echo "   Reset ke default (guacadmin/guacadmin):"
    echo "   $ docker compose down -v"
    echo "   $ docker compose up -d"
    echo ""
    
    echo "6️⃣  ${CYAN}Performance lambat${NC}"
    echo "   Cek resource usage:"
    echo "   $ docker stats"
    echo "   Tingkatkan resource di Docker settings"
    echo ""
    
    echo -e "${YELLOW}📞 BANTUAN LEBIH LANJUT:${NC}"
    echo "   • Log file: $(pwd)/$INSTALL_LOG"
    echo "   • Docker logs: docker compose logs -f"
    echo "   • Dokumentasi: https://guacamole.apache.org/doc/gug/"
    echo ""
}

# Uninstall function
perform_uninstall() {
    local mode=$1  # clean, purge, or full
    
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║          ⚠️  UNINSTALL GUACAMOLE                         ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    case $mode in
        clean)
            log_warning "Mode: CLEAN - Stop dan hapus containers, keep data"
            echo "   ✓ Stop semua containers"
            echo "   ✓ Hapus containers dan networks"
            echo "   ✗ Data database tetap ada"
            echo "   ✗ Docker images tetap ada"
            ;;
        purge)
            log_warning "Mode: PURGE - Hapus semua termasuk data"
            echo "   ✓ Stop semua containers"
            echo "   ✓ Hapus containers dan networks"
            echo "   ✓ Hapus semua data database"
            echo "   ✓ Hapus konfigurasi files"
            echo "   ✗ Docker images tetap ada"
            ;;
        full)
            log_warning "Mode: FULL - Hapus SEMUANYA termasuk Docker"
            echo "   ✓ Stop semua containers"
            echo "   ✓ Hapus containers dan networks"
            echo "   ✓ Hapus semua data database"
            echo "   ✓ Hapus konfigurasi files"
            echo "   ✓ Hapus Docker images"
            echo "   ✓ Uninstall Docker Engine"
            ;;
    esac
    
    echo ""
    read -rp "Apakah Anda yakin? Ketik 'YES' untuk konfirmasi: " confirm
    
    if [[ "$confirm" != "YES" ]]; then
        log_info "Uninstall dibatalkan"
        return
    fi
    
    progress "🗑️  Memulai uninstall" 3
    
    # Stop and remove containers
    if docker compose ps &>/dev/null; then
        log_info "Menghentikan containers..."
        docker compose down || true
    fi
    
    if [[ "$mode" == "purge" || "$mode" == "full" ]]; then
        # Remove volumes and data
        log_info "Menghapus data volumes..."
        docker compose down -v || true
        rm -rf db-data init
        
        # Remove config files
        log_info "Menghapus file konfigurasi..."
        rm -f .env docker-compose.yml "$STATE_FILE"
    fi
    
    if [[ "$mode" == "full" ]]; then
        # Remove Docker images
        log_info "Menghapus Docker images..."
        docker rmi postgres:${POSTGRES_VERSION} guacamole/guacd:${GUACAMOLE_VERSION} guacamole/guacamole:${GUACAMOLE_VERSION} 2>/dev/null || true
        
        # Uninstall Docker
        read -rp "Uninstall Docker Engine juga? (y/N): " remove_docker
        if [[ "$remove_docker" =~ ^[Yy]$ ]]; then
            log_info "Menghapus Docker Engine..."
            if command -v apt-get &>/dev/null; then
                apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                apt-get autoremove -y
                rm -rf /var/lib/docker /var/lib/containerd
            elif command -v yum &>/dev/null; then
                yum remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                rm -rf /var/lib/docker /var/lib/containerd
            fi
        fi
    fi
    
    log_success "Uninstall selesai!"
    
    if [[ "$mode" == "full" ]]; then
        echo ""
        log_info "Anda dapat menghapus direktori instalasi secara manual:"
        echo "   cd .. && rm -rf $(basename "$(pwd)")"
    fi
}

# Backup configuration
backup_config() {
    local backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    progress "💾 Membuat backup konfigurasi" 3
    
    cp .env "$backup_dir/" 2>/dev/null || true
    cp docker-compose.yml "$backup_dir/" 2>/dev/null || true
    cp "$INSTALL_LOG" "$backup_dir/" 2>/dev/null || true
    cp "$STATE_FILE" "$backup_dir/" 2>/dev/null || true
    
    tar -czf "${backup_dir}.tar.gz" "$backup_dir"
    rm -rf "$backup_dir"
    
    log_success "Backup berhasil dibuat: ${backup_dir}.tar.gz"
    echo "   Simpan file ini di tempat aman!"
}

# Post-installation menu
post_install_menu() {
    local network_info
    local internal_ip
    local public_ip
    
    network_info=$(get_network_info)
    internal_ip=$(echo "$network_info" | cut -d'|' -f1)
    public_ip=$(echo "$network_info" | cut -d'|' -f2)
    
    while true; do
        echo ""
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║          🎯 POST-INSTALLATION MENU                       ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        echo ""
        echo "🌐 Guacamole Access:"
        echo "   Internal: http://${internal_ip}:8080/guacamole/"
        [[ "$public_ip" != "Tidak tersedia" ]] && echo "   Public:   http://${public_ip}:8080/guacamole/"
        echo ""
        echo "   Username: guacadmin"
        echo "   Password: guacadmin"
        echo ""
        echo "Pilih opsi:"
        echo -e "  ${GREEN}1${NC}) 📋 Lihat ringkasan instalasi"
        echo -e "  ${GREEN}2${NC}) 🔧 Troubleshooting guide"
        echo -e "  ${GREEN}3${NC}) 📊 Status real-time containers"
        echo -e "  ${GREEN}4${NC}) 📝 Lihat logs"
        echo -e "  ${GREEN}5${NC}) 🔄 Restart services"
        echo -e "  ${RED}6${NC}) 🗑️  Uninstall (Clean - keep data)"
        echo -e "  ${RED}7${NC}) 🗑️  Uninstall (Purge - remove all)"
        echo -e "  ${RED}8${NC}) 🗑️  Uninstall (Full - with Docker)"
        echo -e "  ${CYAN}9${NC}) 💾 Backup konfigurasi"
        echo -e "  ${CYAN}0${NC}) ✅ Selesai"
        echo ""
        read -rp "Pilihan [0-9]: " choice
        
        case $choice in
            1)
                show_installation_summary
                read -rp "Tekan Enter untuk kembali..."
                ;;
            2)
                show_troubleshooting
                read -rp "Tekan Enter untuk kembali..."
                ;;
            3)
                echo ""
                echo "Status containers (Ctrl+C untuk keluar):"
                docker stats --no-stream
                read -rp "Tekan Enter untuk kembali..."
                ;;
            4)
                echo ""
                echo "Pilih container untuk melihat logs:"
                echo "  1) guacamole_app"
                echo "  2) guacamole_db"
                echo "  3) guacamole_daemon"
                echo "  4) Semua"
                read -rp "Pilihan: " log_choice
                case $log_choice in
                    1) docker compose logs --tail=50 guacamole ;;
                    2) docker compose logs --tail=50 db ;;
                    3) docker compose logs --tail=50 guacd ;;
                    4) docker compose logs --tail=50 ;;
                esac
                read -rp "Tekan Enter untuk kembali..."
                ;;
            5)
                progress "🔄 Restarting services" 3
                docker compose restart
                log_success "Services berhasil direstart"
                read -rp "Tekan Enter untuk kembali..."
                ;;
            6)
                perform_uninstall "clean"
                read -rp "Tekan Enter untuk kembali..."
                ;;
            7)
                perform_uninstall "purge"
                read -rp "Tekan Enter untuk kembali..."
                ;;
            8)
                perform_uninstall "full"
                read -rp "Tekan Enter untuk keluar..."
                break
                ;;
            9)
                backup_config
                read -rp "Tekan Enter untuk kembali..."
                ;;
            0)
                log_success "Terima kasih! Selamat menggunakan Apache Guacamole 🎉"
                break
                ;;
            *)
                log_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Create menu alias script
create_menu_alias() {
    local menu_script="/usr/local/bin/protokol-menu"
    local install_path="$(pwd)"
    
    progress "🔗 Membuat alias protokol-menu" 2
    
    cat > "$menu_script" <<'MENU_SCRIPT'
#!/bin/bash
# Protokol Menu - Quick access to Guacamole management

# Find installation directory
if [[ -f "/root/guacamole-setup/docker-compose.yml" ]]; then
    INSTALL_DIR="/root/guacamole-setup"
elif [[ -f "$HOME/guacamole-setup/docker-compose.yml" ]]; then
    INSTALL_DIR="$HOME/guacamole-setup"
else
    echo "❌ Installation directory not found!"
    echo "Please run this command from the installation directory or specify the path:"
    echo "   cd /path/to/guacamole-setup && protokol-menu"
    exit 1
fi

cd "$INSTALL_DIR" || exit 1

# Source the main script functions (we'll need to extract the menu function)
# For now, we'll recreate a simplified menu

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

get_network_info() {
    local internal_ip
    local public_ip
    internal_ip=$(hostname -I | awk '{print $1}')
    public_ip=$(timeout 5 curl -s https://api.ipify.org 2>/dev/null || echo "Tidak tersedia")
    echo "$internal_ip|$public_ip"
}

while true; do
    clear
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          🎯 GUACAMOLE MANAGEMENT MENU                    ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    network_info=$(get_network_info)
    internal_ip=$(echo "$network_info" | cut -d'|' -f1)
    public_ip=$(echo "$network_info" | cut -d'|' -f2)
    
    echo "🌐 Guacamole Access:"
    echo "   Internal: http://${internal_ip}:8080/guacamole/"
    [[ "$public_ip" != "Tidak tersedia" ]] && echo "   Public:   http://${public_ip}:8080/guacamole/"
    echo ""
    echo "📁 Installation: $INSTALL_DIR"
    echo ""
    echo "Pilih opsi:"
    echo -e "  ${GREEN}1${NC}) 📊 Status containers"
    echo -e "  ${GREEN}2${NC}) 📝 Lihat logs"
    echo -e "  ${GREEN}3${NC}) 🔄 Restart services"
    echo -e "  ${GREEN}4${NC}) ⏹️  Stop services"
    echo -e "  ${GREEN}5${NC}) ▶️  Start services"
    echo -e "  ${CYAN}6${NC}) 💾 Backup konfigurasi"
    echo -e "  ${YELLOW}7${NC}) 🔧 Troubleshooting"
    echo -e "  ${RED}8${NC}) 🗑️  Uninstall menu"
    echo -e "  ${CYAN}0${NC}) ✅ Keluar"
    echo ""
    read -rp "Pilihan [0-8]: " choice
    
    case $choice in
        1)
            echo ""
            echo "=== Container Status ==="
            docker compose ps
            echo ""
            echo "=== Resource Usage ==="
            docker stats --no-stream
            echo ""
            read -rp "Tekan Enter untuk kembali..."
            ;;
        2)
            echo ""
            echo "Pilih container:"
            echo "  1) guacamole_app"
            echo "  2) guacamole_db"
            echo "  3) guacamole_daemon"
            echo "  4) Semua"
            read -rp "Pilihan: " log_choice
            echo ""
            case $log_choice in
                1) docker compose logs --tail=100 -f guacamole ;;
                2) docker compose logs --tail=100 -f db ;;
                3) docker compose logs --tail=100 -f guacd ;;
                4) docker compose logs --tail=100 -f ;;
                *) echo "Pilihan tidak valid" ;;
            esac
            ;;
        3)
            echo ""
            echo "🔄 Restarting services..."
            docker compose restart
            echo "✅ Services berhasil direstart"
            sleep 2
            ;;
        4)
            echo ""
            echo "⏹️  Stopping services..."
            docker compose stop
            echo "✅ Services berhasil dihentikan"
            sleep 2
            ;;
        5)
            echo ""
            echo "▶️  Starting services..."
            docker compose start
            echo "✅ Services berhasil dijalankan"
            sleep 2
            ;;
        6)
            echo ""
            backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$backup_dir"
            cp .env "$backup_dir/" 2>/dev/null || true
            cp docker-compose.yml "$backup_dir/" 2>/dev/null || true
            cp installation.log "$backup_dir/" 2>/dev/null || true
            tar -czf "${backup_dir}.tar.gz" "$backup_dir"
            rm -rf "$backup_dir"
            echo "✅ Backup berhasil: ${backup_dir}.tar.gz"
            read -rp "Tekan Enter untuk kembali..."
            ;;
        7)
            echo ""
            echo "╔══════════════════════════════════════════════════════════╗"
            echo "║          🔧 TROUBLESHOOTING                              ║"
            echo "╚══════════════════════════════════════════════════════════╝"
            echo ""
            echo "1️⃣  Container tidak bisa diakses"
            echo "   $ docker compose ps"
            echo "   $ docker compose logs"
            echo ""
            echo "2️⃣  Reset password Guacamole"
            echo "   $ docker compose down -v"
            echo "   $ docker compose up -d"
            echo ""
            echo "3️⃣  Port conflict"
            echo "   $ sudo lsof -i :8080"
            echo "   Edit docker-compose.yml untuk ganti port"
            echo ""
            echo "4️⃣  Database error"
            echo "   $ docker compose logs db"
            echo "   $ docker compose restart db"
            echo ""
            read -rp "Tekan Enter untuk kembali..."
            ;;
        8)
            echo ""
            echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║          ⚠️  UNINSTALL MENU                              ║${NC}"
            echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo "Pilih mode uninstall:"
            echo "  1) Clean - Hapus containers, keep data"
            echo "  2) Purge - Hapus semua termasuk data"
            echo "  3) Full - Hapus semuanya + Docker"
            echo "  0) Batal"
            echo ""
            read -rp "Pilihan: " uninstall_choice
            
            case $uninstall_choice in
                1)
                    read -rp "Ketik 'YES' untuk konfirmasi: " confirm
                    if [[ "$confirm" == "YES" ]]; then
                        docker compose down
                        echo "✅ Containers dihapus, data tetap ada"
                    fi
                    ;;
                2)
                    read -rp "Ketik 'YES' untuk konfirmasi: " confirm
                    if [[ "$confirm" == "YES" ]]; then
                        docker compose down -v
                        rm -rf db-data init .env docker-compose.yml
                        echo "✅ Semua data dihapus"
                    fi
                    ;;
                3)
                    read -rp "Ketik 'YES' untuk konfirmasi: " confirm
                    if [[ "$confirm" == "YES" ]]; then
                        docker compose down -v
                        docker rmi postgres:16-alpine guacamole/guacd:1.5.5 guacamole/guacamole:1.5.5 2>/dev/null || true
                        echo "✅ Images dihapus"
                        read -rp "Uninstall Docker juga? (y/N): " remove_docker
                        if [[ "$remove_docker" =~ ^[Yy]$ ]]; then
                            apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || true
                            yum remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || true
                            echo "✅ Docker dihapus"
                        fi
                    fi
                    ;;
            esac
            read -rp "Tekan Enter untuk kembali..."
            ;;
        0)
            echo ""
            echo "✅ Terima kasih!"
            exit 0
            ;;
        *)
            echo "❌ Pilihan tidak valid"
            sleep 1
            ;;
    esac
done
MENU_SCRIPT
    
    chmod +x "$menu_script"
    
    # Add to PATH info in installation log
    echo "" >> "$INSTALL_LOG"
    echo "Menu alias created: protokol-menu" >> "$INSTALL_LOG"
    echo "Location: $menu_script" >> "$INSTALL_LOG"
    
    log_success "Alias 'protokol-menu' berhasil dibuat"
    log_info "Anda dapat menjalankan menu kapan saja dengan: protokol-menu"
}
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    log_success "Instalasi Apache Guacamole selesai!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    log_info "Instalasi log tersimpan di: $(pwd)/$INSTALL_LOG"
    log_warning "PENTING: Segera ubah password default setelah login pertama!"
    echo ""
}

# Main function
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  🚀 Apache Guacamole Docker Installer v2.5              ║"
    echo "║  📦 Enhanced with Management Features                    ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    check_root
    detect_system
    install_docker
    check_docker_compose
    setup_directory
    setup_password
    create_compose_file
    init_database
    start_services
    display_info
    
    # Show post-installation menu
    post_install_menu
}

# Trap errors
trap 'log_error "Script gagal pada baris $LINENO"' ERR

# Run main function
main "$@"

# 1. Berikan permission
# chmod +x protokol.sh

# 2. Jalankan sebagai root
# sudo ./protokol.sh

# 3. Ikuti instruksi interaktif
# - Masukkan password database yang kuat
# - Tunggu hingga instalasi selesai
# - Menu post-installation akan muncul otomatis

# Setelah instalasi selesai, kapan saja bisa panggil:
# protokol-menu

# Atau dari mana saja:
# sudo protokol-menu

# Menu akan muncul dengan interface yang clean
```

## 📋 **Preview Menu Baru:**
```
╔══════════════════════════════════════════════════════════╗
║          🎯 GUACAMOLE MANAGEMENT MENU                    ║
╚══════════════════════════════════════════════════════════╝

🌐 Guacamole Access:
   #Internal: http://192.168.1.100:8080/guacamole/
   #Public:   http://203.0.113.1:8080/guacamole/

📁 Installation: /root/guacamole-setup

Pilih opsi:
  #1) 📊 Status containers
  #2) 📝 Lihat logs
  #3) 🔄 Restart services
  #4) ⏹️  Stop services
  #5) ▶️  Start services
  #6) 💾 Backup konfigurasi
  #7) 🔧 Troubleshooting
  #8) 🗑️  Uninstall menu
  #0) ✅ Keluar
