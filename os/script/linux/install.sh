#!/bin/bash

################################################################################
# Apache Guacamole Installer - Completely Rebuilt
# Version: 4.0.0
# Supports: Ubuntu 20.04/22.04/24.04, Debian 11/12, CentOS/RHEL 8+
################################################################################

# Strict mode
set -e
set -o pipefail

################################################################################
# CONFIGURATION
################################################################################

GUAC_VERSION="1.5.5"
POSTGRES_JDBC_VERSION="42.7.3"
INSTALL_DIR="/opt/guacamole"
LOG_FILE="/var/log/guacamole-install.log"

# Colors
R='\033[0;31m' # Red
G='\033[0;32m' # Green
Y='\033[1;33m' # Yellow
B='\033[0;34m' # Blue
NC='\033[0m'   # No Color

################################################################################
# LOGGING FUNCTIONS
################################################################################

log_info() {
    echo -e "${B}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${G}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${Y}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${R}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
}

print_banner() {
    clear
    echo -e "${B}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║     Apache Guacamole Installer v4.0                     ║
║     Rebuilt from Scratch - Simple & Robust              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

################################################################################
# PREREQUISITE CHECKS
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${R}ERROR: This script must be run as root${NC}"
        echo -e "${Y}Please run: sudo bash $0${NC}"
        exit 1
    fi
}

check_system() {
    log_info "Checking system compatibility..."
    
    # Check if running on supported OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "Detected OS: $NAME $VERSION"
        
        case "$ID" in
            ubuntu|debian)
                PKG_MGR="apt"
                ;;
            centos|rhel|rocky|almalinux)
                PKG_MGR="yum"
                ;;
            fedora)
                PKG_MGR="dnf"
                ;;
            *)
                log_error "Unsupported OS: $ID"
                exit 1
                ;;
        esac
    else
        log_error "Cannot detect OS"
        exit 1
    fi
    
    # Check memory
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $total_mem -lt 1024 ]]; then
        log_warn "Low memory detected: ${total_mem}MB (recommended: 2GB+)"
    fi
    
    # Check disk space
    free_space=$(df -m / | awk 'NR==2 {print $4}')
    if [[ $free_space -lt 3000 ]]; then
        log_warn "Low disk space: ${free_space}MB (recommended: 5GB+)"
    fi
    
    log_success "System check passed"
}

################################################################################
# USER INPUT
################################################################################

get_user_input() {
    log_info "Collecting configuration..."
    
    echo ""
    echo -e "${B}=== Database Configuration ===${NC}"
    read -p "Database name [guacamole_db]: " DB_NAME
    DB_NAME=${DB_NAME:-guacamole_db}
    
    read -p "Database user [guacamole]: " DB_USER
    DB_USER=${DB_USER:-guacamole}
    
    read -sp "Database password (leave empty to auto-generate): " DB_PASS
    echo ""
    if [[ -z "$DB_PASS" ]]; then
        DB_PASS=$(openssl rand -base64 18 | tr -d "=+/" | cut -c1-16)
        log_warn "Auto-generated database password"
    fi
    
    echo ""
    echo -e "${B}=== Guacamole Admin Account ===${NC}"
    read -p "Admin username [guacadmin]: " GUAC_USER
    GUAC_USER=${GUAC_USER:-guacadmin}
    
    read -sp "Admin password (leave empty to auto-generate): " GUAC_PASS
    echo ""
    if [[ -z "$GUAC_PASS" ]]; then
        GUAC_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
        log_warn "Auto-generated admin password"
    fi
    
    echo ""
    echo -e "${B}=== Network Configuration ===${NC}"
    read -p "Domain name (leave empty to use IP): " DOMAIN
    
    if [[ -n "$DOMAIN" ]]; then
        read -p "Enable SSL with Let's Encrypt? (y/n) [n]: " ENABLE_SSL
        ENABLE_SSL=${ENABLE_SSL:-n}
    else
        ENABLE_SSL="n"
    fi
    
    # Save configuration
    mkdir -p "$INSTALL_DIR"
    cat > "$INSTALL_DIR/config.env" <<EOF
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
GUAC_USER=$GUAC_USER
GUAC_PASS=$GUAC_PASS
DOMAIN=$DOMAIN
ENABLE_SSL=$ENABLE_SSL
GUAC_VERSION=$GUAC_VERSION
POSTGRES_JDBC_VERSION=$POSTGRES_JDBC_VERSION
EOF
    chmod 600 "$INSTALL_DIR/config.env"
    
    log_success "Configuration saved"
}

################################################################################
# INSTALLATION FUNCTIONS
################################################################################

install_dependencies() {
    log_info "Installing dependencies..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    if [[ "$PKG_MGR" == "apt" ]]; then
        apt-get update -qq
        apt-get install -y \
            build-essential libcairo2-dev libjpeg-turbo8-dev libpng-dev \
            libtool-bin libossp-uuid-dev libavcodec-dev libavformat-dev \
            libavutil-dev libswscale-dev freerdp2-dev libpango1.0-dev \
            libssh2-1-dev libtelnet-dev libvncserver-dev libwebsockets-dev \
            libpulse-dev libssl-dev libvorbis-dev libwebp-dev \
            wget curl git nginx postgresql postgresql-contrib \
            openjdk-17-jdk tomcat10 certbot python3-certbot-nginx \
            >> "$LOG_FILE" 2>&1
        
        TOMCAT_VERSION="tomcat10"
        TOMCAT_USER="tomcat"
        
    elif [[ "$PKG_MGR" == "yum" ]] || [[ "$PKG_MGR" == "dnf" ]]; then
        $PKG_MGR install -y epel-release
        $PKG_MGR groupinstall -y "Development Tools"
        $PKG_MGR install -y \
            cairo-devel libjpeg-turbo-devel libpng-devel libtool uuid-devel \
            ffmpeg-devel pango-devel libssh2-devel libtelnet-devel \
            libvncserver-devel libwebsockets-devel pulseaudio-libs-devel \
            openssl-devel libvorbis-devel libwebp-devel \
            wget curl git nginx postgresql-server postgresql-contrib \
            java-17-openjdk-devel tomcat certbot python3-certbot-nginx \
            >> "$LOG_FILE" 2>&1
        
        TOMCAT_VERSION="tomcat"
        TOMCAT_USER="tomcat"
    fi
    
    log_success "Dependencies installed"
}

setup_postgresql() {
    log_info "Setting up PostgreSQL..."
    
    source "$INSTALL_DIR/config.env"
    
    if [[ "$PKG_MGR" == "apt" ]]; then
        systemctl start postgresql
        systemctl enable postgresql
        
    elif [[ "$PKG_MGR" == "yum" ]] || [[ "$PKG_MGR" == "dnf" ]]; then
        if [[ ! -d "/var/lib/pgsql/data/base" ]]; then
            postgresql-setup --initdb >> "$LOG_FILE" 2>&1
        fi
        
        # Configure authentication
        sed -i 's/^local.*all.*all.*peer$/local   all             all                                     md5/' \
            /var/lib/pgsql/data/pg_hba.conf 2>/dev/null || true
        
        systemctl start postgresql
        systemctl enable postgresql
    fi
    
    # Wait for PostgreSQL to be ready
    sleep 3
    
    # Create database and user
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
    sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    sudo -u postgres psql -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO $DB_USER;"
    
    log_success "PostgreSQL configured"
}

install_guacamole_server() {
    log_info "Installing Guacamole Server $GUAC_VERSION..."
    
    cd /tmp
    
    # Download
    if [[ ! -f "guacamole-server-${GUAC_VERSION}.tar.gz" ]]; then
        wget -q "https://downloads.apache.org/guacamole/${GUAC_VERSION}/source/guacamole-server-${GUAC_VERSION}.tar.gz"
    fi
    
    # Extract
    tar -xzf "guacamole-server-${GUAC_VERSION}.tar.gz"
    cd "guacamole-server-${GUAC_VERSION}"
    
    # Compile (this takes time)
    log_info "Compiling Guacamole Server (5-10 minutes)..."
    ./configure --with-init-dir=/etc/init.d >> "$LOG_FILE" 2>&1
    make -j$(nproc) >> "$LOG_FILE" 2>&1
    make install >> "$LOG_FILE" 2>&1
    ldconfig
    
    # Create systemd service
    cat > /etc/systemd/system/guacd.service <<'EOF'
[Unit]
Description=Guacamole Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/sbin/guacd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable guacd
    systemctl start guacd
    
    # Verify
    sleep 2
    if ! systemctl is-active --quiet guacd; then
        log_error "Failed to start guacd"
        exit 1
    fi
    
    log_success "Guacamole Server installed"
}

install_guacamole_client() {
    log_info "Installing Guacamole Client $GUAC_VERSION..."
    
    source "$INSTALL_DIR/config.env"
    cd /tmp
    
    # Download client WAR
    if [[ ! -f "guacamole-${GUAC_VERSION}.war" ]]; then
        wget -q "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war"
    fi
    
    # Download JDBC authentication
    if [[ ! -f "guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz" ]]; then
        wget -q "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz"
    fi
    
    # Download PostgreSQL JDBC driver
    if [[ ! -f "postgresql-${POSTGRES_JDBC_VERSION}.jar" ]]; then
        wget -q "https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar"
    fi
    
    # Setup directories
    mkdir -p /etc/guacamole/{extensions,lib}
    
    # Deploy WAR file
    if [[ "$PKG_MGR" == "apt" ]]; then
        cp "guacamole-${GUAC_VERSION}.war" "/var/lib/tomcat10/webapps/guacamole.war"
    else
        cp "guacamole-${GUAC_VERSION}.war" "/var/lib/tomcat/webapps/guacamole.war"
    fi
    
    # Install JDBC driver
    cp "postgresql-${POSTGRES_JDBC_VERSION}.jar" /etc/guacamole/lib/
    
    # Install JDBC authentication extension
    tar -xzf "guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz"
    cp "guacamole-auth-jdbc-${GUAC_VERSION}/postgresql/guacamole-auth-jdbc-postgresql-${GUAC_VERSION}.jar" \
        /etc/guacamole/extensions/
    
    # Initialize database schema
    log_info "Initializing database schema..."
    cat "guacamole-auth-jdbc-${GUAC_VERSION}/postgresql/schema/"*.sql | \
        PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d "$DB_NAME" >> "$LOG_FILE" 2>&1
    
    # Create guacamole.properties
    cat > /etc/guacamole/guacamole.properties <<EOF
# PostgreSQL
postgresql-hostname: localhost
postgresql-port: 5432
postgresql-database: $DB_NAME
postgresql-username: $DB_USER
postgresql-password: $DB_PASS
EOF
    
    chmod 600 /etc/guacamole/guacamole.properties
    
    # Configure Tomcat
    if [[ "$PKG_MGR" == "apt" ]]; then
        echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/default/tomcat10
        systemctl restart tomcat10
    else
        echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/tomcat/tomcat.conf
        systemctl restart tomcat
    fi
    
    # Wait for Tomcat
    log_info "Waiting for Tomcat to deploy Guacamole..."
    sleep 15
    
    log_success "Guacamole Client installed"
}

configure_nginx() {
    log_info "Configuring Nginx..."
    
    source "$INSTALL_DIR/config.env"
    
    if [[ -z "$DOMAIN" ]]; then
        SERVER_NAME=$(curl -s ifconfig.me || echo "localhost")
    else
        SERVER_NAME="$DOMAIN"
    fi
    
    # Create Nginx config
    if [[ -d /etc/nginx/sites-available ]]; then
        NGINX_CONF="/etc/nginx/sites-available/guacamole"
    else
        NGINX_CONF="/etc/nginx/conf.d/guacamole.conf"
    fi
    
    cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $SERVER_NAME;

    location / {
        proxy_pass http://localhost:8080/guacamole/;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$http_connection;
        proxy_cookie_path /guacamole/ /;
    }
}
EOF
    
    # Enable site (Ubuntu/Debian)
    if [[ -d /etc/nginx/sites-enabled ]]; then
        ln -sf /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
    fi
    
    # Test and restart Nginx
    nginx -t >> "$LOG_FILE" 2>&1
    systemctl restart nginx
    systemctl enable nginx
    
    log_success "Nginx configured"
}

setup_ssl() {
    source "$INSTALL_DIR/config.env"
    
    if [[ "$ENABLE_SSL" == "y" ]] && [[ -n "$DOMAIN" ]]; then
        log_info "Setting up SSL certificate..."
        
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos \
            --register-unsafely-without-email >> "$LOG_FILE" 2>&1 || {
            log_warn "SSL setup failed, continuing without SSL"
            return 0
        }
        
        log_success "SSL certificate installed"
    fi
}

configure_firewall() {
    log_info "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        ufw --force allow 22/tcp
        ufw --force allow 80/tcp
        ufw --force allow 443/tcp
        echo "y" | ufw enable
        log_success "UFW firewall configured"
        
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --reload
        log_success "Firewalld configured"
    else
        log_warn "No firewall detected"
    fi
}

################################################################################
# POST-INSTALLATION
################################################################################

verify_installation() {
    log_info "Verifying installation..."
    
    local errors=0
    
    # Check services
    for service in guacd postgresql nginx; do
        if systemctl is-active --quiet "$service"; then
            log_success "$service is running"
        else
            log_error "$service is not running"
            ((errors++))
        fi
    done
    
    # Check Tomcat
    if [[ "$PKG_MGR" == "apt" ]]; then
        if systemctl is-active --quiet tomcat10; then
            log_success "tomcat10 is running"
        else
            log_error "tomcat10 is not running"
            ((errors++))
        fi
    else
        if systemctl is-active --quiet tomcat; then
            log_success "tomcat is running"
        else
            log_error "tomcat is not running"
            ((errors++))
        fi
    fi
    
    # Test web interface
    sleep 5
    if curl -s http://localhost:8080/guacamole/ | grep -q "Guacamole"; then
        log_success "Web interface is accessible"
    else
        log_warn "Web interface not ready yet (may need a few more seconds)"
    fi
    
    if [[ $errors -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

print_summary() {
    source "$INSTALL_DIR/config.env"
    
    if [[ -z "$DOMAIN" ]]; then
        ACCESS_URL="http://$(curl -s ifconfig.me)"
    else
        if [[ "$ENABLE_SSL" == "y" ]]; then
            ACCESS_URL="https://$DOMAIN"
        else
            ACCESS_URL="http://$DOMAIN"
        fi
    fi
    
    echo ""
    echo -e "${G}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${G}║                                                          ║${NC}"
    echo -e "${G}║          ✓ INSTALLATION COMPLETED!                      ║${NC}"
    echo -e "${G}║                                                          ║${NC}"
    echo -e "${G}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${B}Access Information:${NC}"
    echo -e "  URL:      ${Y}$ACCESS_URL${NC}"
    echo -e "  Username: ${Y}$GUAC_USER${NC}"
    echo -e "  Password: ${Y}$GUAC_PASS${NC}"
    echo ""
    echo -e "${B}Database Information:${NC}"
    echo -e "  Database: ${Y}$DB_NAME${NC}"
    echo -e "  User:     ${Y}$DB_USER${NC}"
    echo -e "  Password: ${Y}$DB_PASS${NC}"
    echo ""
    echo -e "${Y}⚠  Save this information securely!${NC}"
    echo -e "${Y}⚠  Default password is 'guacadmin' - change it after first login${NC}"
    echo ""
    echo -e "Configuration saved to: ${B}$INSTALL_DIR/config.env${NC}"
    echo -e "Installation log: ${B}$LOG_FILE${NC}"
    echo ""
}

################################################################################
# MAIN INSTALLATION FLOW
################################################################################

run_installation() {
    print_banner
    
    log_info "Starting Guacamole installation..."
    echo "" > "$LOG_FILE"
    
    check_root
    check_system
    get_user_input
    
    echo ""
    log_info "Installing components (this will take 10-15 minutes)..."
    echo ""
    
    install_dependencies
    setup_postgresql
    install_guacamole_server
    install_guacamole_client
    configure_nginx
    setup_ssl
    configure_firewall
    
    echo ""
    if verify_installation; then
        print_summary
    else
        log_error "Installation completed with warnings"
        echo ""
        echo "Check the log file for details: $LOG_FILE"
        echo ""
    fi
}

################################################################################
# MENU
################################################################################

show_menu() {
    print_banner
    
    echo "Choose an option:"
    echo ""
    echo "  1) Install Guacamole"
    echo "  2) Uninstall Guacamole"
    echo "  3) View Installation Log"
    echo "  4) Check Status"
    echo "  5) Exit"
    echo ""
    read -p "Enter choice [1-5]: " choice
    
    case $choice in
        1)
            run_installation
            ;;
        2)
            uninstall_guacamole
            ;;
        3)
            if [[ -f "$LOG_FILE" ]]; then
                less "$LOG_FILE"
            else
                echo "Log file not found"
            fi
            read -p "Press Enter to continue..."
            show_menu
            ;;
        4)
            check_status
            read -p "Press Enter to continue..."
            show_menu
            ;;
        5)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid choice"
            sleep 2
            show_menu
            ;;
    esac
}

check_status() {
    print_banner
    echo "System Status:"
    echo ""
    
    for service in guacd postgresql nginx tomcat tomcat10; do
        if systemctl list-units --all | grep -q "$service.service"; then
            if systemctl is-active --quiet "$service"; then
                echo -e "  $service: ${G}✓ Running${NC}"
            else
                echo -e "  $service: ${R}✗ Stopped${NC}"
            fi
        fi
    done
    echo ""
}

uninstall_guacamole() {
    print_banner
    echo -e "${R}WARNING: This will remove Guacamole completely!${NC}"
    echo ""
    read -p "Are you sure? (type 'yes' to confirm): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Cancelled"
        sleep 2
        show_menu
        return
    fi
    
    log_info "Uninstalling Guacamole..."
    
    # Stop services
    systemctl stop guacd 2>/dev/null || true
    systemctl stop tomcat10 2>/dev/null || true
    systemctl stop tomcat 2>/dev/null || true
    systemctl disable guacd 2>/dev/null || true
    
    # Remove files
    rm -rf /etc/guacamole
    rm -f /usr/local/sbin/guacd
    rm -rf /usr/local/lib/libguac*
    rm -f /etc/systemd/system/guacd.service
    rm -f /var/lib/tomcat*/webapps/guacamole.war
    rm -rf /var/lib/tomcat*/webapps/guacamole
    rm -f /etc/nginx/sites-*/guacamole
    rm -f /etc/nginx/conf.d/guacamole.conf
    rm -rf "$INSTALL_DIR"
    
    # Remove database
    if [[ -f "$INSTALL_DIR/config.env" ]]; then
        source "$INSTALL_DIR/config.env"
        sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
        sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" 2>/dev/null || true
    fi
    
    systemctl daemon-reload
    
    log_success "Guacamole uninstalled"
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

################################################################################
# ENTRY POINT
################################################################################

main() {
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Run
    show_menu
}

# Execute
main
