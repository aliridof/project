#!/bin/bash

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# Fungsi untuk membersihkan layar
clear_screen() {
    clear
}

# Fungsi untuk menampilkan header
show_header() {
    echo -e "${CYAN}[------------------------------------------------------------]${NC}"
    echo -e "${CYAN}[--------------------]${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${CYAN}[--------------------]${NC}"
}

# Fungsi untuk menampilkan footer
show_footer() {
    echo -e "${CYAN}[-------------------->${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${CYAN}[--------------------]${NC}"
    echo -e "${CYAN}[------------------------------------------------------------]${NC}"
}

# Fungsi untuk menampilkan pesan sukses
show_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    sleep 2
}

# Fungsi untuk menampilkan pesan error
show_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    sleep 2
}

# Fungsi untuk menampilkan pesan info
show_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    sleep 2
}

# Fungsi untuk meminta input
get_input() {
    echo -e "${YELLOW}$1${NC}"
    read -p "> " input
    echo $input
}

# Fungsi untuk meminta konfirmasi
get_confirmation() {
    echo -e "${YELLOW}$1 (y/n)${NC}"
    read -p "> " confirm
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        return 0
    else
        return 1
    fi
}

# Fungsi untuk memeriksa apakah user adalah root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        show_error "Script ini harus dijalankan sebagai root!"
        exit 1
    fi
}

# Fungsi untuk menunggu user menekan enter
wait_enter() {
    echo -e "${YELLOW}Tekan Enter untuk melanjutkan...${NC}"
    read
}

# Fungsi untuk memeriksa apakah paket sudah terinstal
is_package_installed() {
    dpkg -l | grep -q "^ii  $1 "
    return $?
}

# Fungsi untuk memeriksa apakah service berjalan
is_service_active() {
    systemctl is-active --quiet $1
    return $?
}

# Fungsi untuk memeriksa apakah service diaktifkan saat boot
is_service_enabled() {
    systemctl is-enabled --quiet $1
    return $?
}

# Fungsi untuk memeriksa apakah firewall aktif
is_firewall_active() {
    ufw status | grep -q "Status: active"
    return $?
}

# Fungsi untuk memeriksa apakah port terbuka
is_port_open() {
    ufw status | grep -q "$1"
    return $?
}

# Fungsi untuk memeriksa apakah user ada
is_user_exists() {
    id "$1" &>/dev/null
    return $?
}

# Fungsi untuk memeriksa apakah user adalah sudo
is_user_sudo() {
    groups "$1" | grep -q "sudo"
    return $?
}

# Fungsi untuk memeriksa apakah swap file ada
is_swap_file_exists() {
    [ -f "/swapfile" ]
    return $?
}

# Fungsi untuk memeriksa apakah swap aktif
is_swap_active() {
    swapon --show | grep -q "/swapfile"
    return $?
}

# Fungsi untuk memeriksa apakah direktori backup ada
is_backup_dir_exists() {
    [ -d "/backups" ]
    return $?
}

# Fungsi untuk memeriksa apakah Nginx terinstal
is_nginx_installed() {
    is_package_installed "nginx"
    return $?
}

# Fungsi untuk memeriksa apakah virtual host Nginx ada
is_nginx_vhost_exists() {
    [ -f "/etc/nginx/sites-available/$1" ]
    return $?
}

# Fungsi untuk memeriksa apakah virtual host Nginx aktif
is_nginx_vhost_enabled() {
    [ -L "/etc/nginx/sites-enabled/$1" ]
    return $?
}

# Fungsi untuk memeriksa apakah RDP terinstal
is_rdp_installed() {
    is_package_installed "xrdp"
    return $?
}

# Fungsi untuk memeriksa apakah VNC terinstal
is_vnc_installed() {
    is_package_installed "tightvncserver"
    return $?
}

# Fungsi untuk membuat direktori backup jika belum ada
create_backup_dir() {
    if ! is_backup_dir_exists; then
        mkdir -p /backups
        show_success "Direktori backup dibuat di /backups"
    fi
}

# Fungsi untuk membuat backup sistem
backup_system() {
    create_backup_dir
    local backup_name="system_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    show_info "Membuat backup sistem..."
    tar -czpf /backups/$backup_name --exclude=/backups --exclude=/proc --exclude=/tmp --exclude=/mnt --exclude=/dev --exclude=/sys --exclude=/run --exclude=/var/cache --exclude=/var/lock --exclude=/var/tmp --exclude=/var/log --exclude=/lost+found /
    if [ $? -eq 0 ]; then
        show_success "Backup sistem berhasil disimpan di /backups/$backup_name"
    else
        show_error "Gagal membuat backup sistem"
    fi
}

# Fungsi untuk restore sistem
restore_system() {
    create_backup_dir
    local backups=($(ls -t /backups/system_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        show_error "Tidak ada backup yang ditemukan"
        return
    fi
    
    clear_screen
    show_header "PROTOCOL-MENU/3. SYSTEM/5. RECOVERY/2. RESTORE"
    echo -e "${YELLOW}BACKUP - LIST${NC}"
    echo ""
    
    for i in "${!backups[@]}"; do
        echo -e "${CYAN}$((i+1)).${NC} ${backups[$i]##*/}"
    done
    
    echo ""
    local choice=$(get_input "PICK BACKUP TO RESTORE")
    
    if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#backups[@]} ]; then
        local selected_backup="${backups[$((choice-1))]}"
        
        if get_confirmation "Apakah Anda yakin ingin restore dari $selected_backup? Ini akan menimpa file sistem yang ada."; then
            show_info "Melakukan restore dari $selected_backup..."
            tar -xpf /backups/$selected_backup -C /
            if [ $? -eq 0 ]; then
                show_success "Restore sistem berhasil"
            else
                show_error "Gagal melakukan restore sistem"
            fi
        else
            show_info "Restore dibatalkan"
        fi
    else
        show_error "Pilihan tidak valid"
    fi
}

# Fungsi untuk membuat swap file
create_swap() {
    local size_gb=$1
    local size_bytes=$((size_gb * 1024 * 1024 * 1024))
    
    if is_swap_file_exists; then
        if get_confirmation "File swap sudah ada. Apakah Anda ingin menghapusnya dan membuat yang baru?"; then
            swapoff /swapfile
            rm /swapfile
            show_success "File swap lama dihapus"
        else
            show_info "Operasi dibatalkan"
            return
        fi
    fi
    
    show_info "Membuat file swap sebesar ${size_gb}GB..."
    fallocate -l ${size_bytes} /swapfile
    
    if [ $? -eq 0 ]; then
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        
        # Tambahkan ke fstab jika belum ada
        if ! grep -q "/swapfile" /etc/fstab; then
            echo "/swapfile none swap sw 0 0" >> /etc/fstab
        fi
        
        show_success "File swap sebesar ${size_gb}GB berhasil dibuat dan diaktifkan"
    else
        show_error "Gagal membuat file swap"
    fi
}

# Fungsi untuk menambah user
add_user() {
    local username=$(get_input "USER-ADD-NAME")
    
    if is_user_exists "$username"; then
        show_error "User $username sudah ada"
        return
    fi
    
    local password=$(get_input "USER-ADD-PASSWORD")
    local access_choice=$(get_input "USER-ADD-ACCESS\n1. ROOT\n2. NON-ROOT")
    
    useradd -m -s /bin/bash "$username"
    echo "$username:$password" | chpasswd
    
    if [ "$access_choice" == "1" ]; then
        usermod -aG sudo "$username"
        show_success "User $username berhasil ditambahkan dengan akses root"
    else
        show_success "User $username berhasil ditambahkan dengan akses non-root"
    fi
}

# Fungsi untuk menampilkan daftar user
list_users() {
    clear_screen
    show_header "PROTOCOL-MENU/4. USER/1. USER-LISTS/"
    echo -e "${YELLOW}USER-LISTS WITH NUMBER${NC}"
    echo ""
    
    local users=($(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd))
    
    for i in "${!users[@]}"; do
        local user="${users[$i]}"
        if is_user_sudo "$user"; then
            echo -e "${CYAN}$((i+1)).${NC} $user (ROOT)"
        else
            echo -e "${CYAN}$((i+1)).${NC} $user (NON-ROOT)"
        fi
    done
    
    echo ""
    local choice=$(get_input "PICK NUMBER")
    
    if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#users[@]} ]; then
        local selected_user="${users[$((choice-1))]}"
        
        clear_screen
        show_header "PROTOCOL-MENU/4. USER/1. USER-LISTS/"
        echo -e "${YELLOW}User yang dipilih: $selected_user${NC}"
        echo ""
        echo -e "${CYAN}1.${NC} USER-SELECTED-EDIT"
        echo -e "${CYAN}2.${NC} USER-SELECTED-REMOVE"
        echo ""
        local action=$(get_input "Pilih aksi")
        
        case $action in
            1)
                edit_user "$selected_user"
                ;;
            2)
                if get_confirmation "Apakah Anda yakin ingin menghapus user $selected_user?"; then
                    userdel -r "$selected_user"
                    show_success "User $selected_user berhasil dihapus"
                else
                    show_info "Penghapusan user dibatalkan"
                fi
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    else
        show_error "Pilihan tidak valid"
    fi
}

# Fungsi untuk mengedit user
edit_user() {
    local username=$1
    
    clear_screen
    show_header "PROTOCOL-MENU/4. USER/1. USER-LISTS/1. USER-SELECTED-EDIT/"
    echo -e "${YELLOW}User yang diedit: $username${NC}"
    echo ""
    echo -e "${CYAN}1.${NC} USER-SELECTED-EDIT-NAME"
    echo -e "${CYAN}2.${NC} USER-SELECTED-EDIT-PASSWORD"
    echo -e "${CYAN}3.${NC} USER-SELECTED-EDIT-ACCESS"
    echo ""
    local choice=$(get_input "Pilih opsi")
    
    case $choice in
        1)
            local new_name=$(get_input "Masukkan nama user baru")
            if is_user_exists "$new_name"; then
                show_error "User $new_name sudah ada"
            else
                usermod -l "$new_name" "$username"
                usermod -d /home/"$new_name" -m "$new_name"
                show_success "Nama user berhasil diubah dari $username menjadi $new_name"
            fi
            ;;
        2)
            local new_password=$(get_input "Masukkan password baru")
            echo "$username:$new_password" | chpasswd
            show_success "Password user $username berhasil diubah"
            ;;
        3)
            local access_choice=$(get_input "USER-SELECTED-EDIT-ACCESS\n1. ROOT\n2. NON-ROOT")
            if [ "$access_choice" == "1" ]; then
                usermod -aG sudo "$username"
                show_success "User $username sekarang memiliki akses root"
            else
                gpasswd -d "$username" sudo
                show_success "User $username sekarang memiliki akses non-root"
            fi
            ;;
        *)
            show_error "Pilihan tidak valid"
            ;;
    esac
}

# Fungsi untuk menampilkan daftar aturan firewall
list_firewall_rules() {
    clear_screen
    show_header "PROTOCOL-MENU/6. NETWORK/2. FIREWALL/1. FIREWALL-LISTS/"
    echo -e "${YELLOW}FIREWALL-LISTS WITH NUMBER${NC}"
    echo ""
    
    if ! is_firewall_active; then
        show_error "Firewall tidak aktif"
        wait_enter
        return
    fi
    
    local rules=($(ufw status numbered | grep -E "^\[.*\]" | awk '{print $2}' | tr -d '[]'))
    
    for i in "${!rules[@]}"; do
        echo -e "${CYAN}${rules[$i]}.${NC} $(ufw status numbered | grep -E "^\[${rules[$i]}\]" | cut -d']' -f2-)"
    done
    
    echo ""
    local choice=$(get_input "PICK NUMBER")
    
    if [[ $choice =~ ^[0-9]+$ ]]; then
        for i in "${!rules[@]}"; do
            if [ "${rules[$i]}" == "$choice" ]; then
                clear_screen
                show_header "PROTOCOL-MENU/6. NETWORK/2. FIREWALL/1. FIREWALL-LISTS/"
                echo -e "${YELLOW}Aturan yang dipilih: $(ufw status numbered | grep -E "^\[${rules[$i]}\]" | cut -d']' -f2-)${NC}"
                echo ""
                echo -e "${CYAN}1.${NC} FIREWALL-SELECTED-EDIT"
                echo -e "${CYAN}2.${NC} FIREWALL-SELECTED-REMOVE"
                echo ""
                local action=$(get_input "Pilih aksi")
                
                case $action in
                    1)
                        show_info "Fitur edit aturan firewall belum diimplementasikan"
                        ;;
                    2)
                        if get_confirmation "Apakah Anda yakin ingin menghapus aturan ini?"; then
                            ufw --force delete $choice
                            show_success "Aturan firewall berhasil dihapus"
                        else
                            show_info "Penghapusan aturan dibatalkan"
                        fi
                        ;;
                    *)
                        show_error "Pilihan tidak valid"
                        ;;
                esac
                return
            fi
        done
        show_error "Pilihan tidak valid"
    else
        show_error "Pilihan tidak valid"
    fi
}

# Fungsi untuk menambah aturan firewall
add_firewall_rule() {
    clear_screen
    show_header "PROTOCOL-MENU/6. NETWORK/2. FIREWALL/2. FIREWALL-ADD/"
    echo ""
    echo -e "${CYAN}1.${NC} Izinkan port"
    echo -e "${CYAN}2.${NC} Blokir port"
    echo -e "${CYAN}3.${NC} Izinkan aplikasi"
    echo -e "${CYAN}4.${NC} Blokir aplikasi"
    echo ""
    local choice=$(get_input "Pilih opsi")
    
    case $choice in
        1)
            local port=$(get_input "Masukkan port yang ingin diizinkan")
            local protocol=$(get_input "Pilih protokol (tcp/udp/both)")
            
            if [ "$protocol" == "both" ]; then
                ufw allow $port
            else
                ufw allow $port/$protocol
            fi
            
            show_success "Port $port berhasil diizinkan"
            ;;
        2)
            local port=$(get_input "Masukkan port yang ingin diblokir")
            local protocol=$(get_input "Pilih protokol (tcp/udp/both)")
            
            if [ "$protocol" == "both" ]; then
                ufw deny $port
            else
                ufw deny $port/$protocol
            fi
            
            show_success "Port $port berhasil diblokir"
            ;;
        3)
            local app=$(get_input "Masukkan nama aplikasi yang ingin diizinkan")
            ufw allow $app
            show_success "Aplikasi $app berhasil diizinkan"
            ;;
        4)
            local app=$(get_input "Masukkan nama aplikasi yang ingin diblokir")
            ufw deny $app
            show_success "Aplikasi $app berhasil diblokir"
            ;;
        *)
            show_error "Pilihan tidak valid"
            ;;
    esac
}

# Fungsi untuk konfigurasi firewall otomatis
auto_firewall() {
    clear_screen
    show_header "PROTOCOL-MENU/6. NETWORK/2. FIREWALL/3. FIREWALL-AUTO/"
    echo ""
    echo -e "${CYAN}1.${NC} FIREWALL-ALL-ALLOW"
    echo -e "${CYAN}2.${NC} FIREWALL-ALL-DISALLOW"
    echo ""
    local choice=$(get_input "Pilih opsi")
    
    case $choice in
        1)
            ufw --force reset
            ufw default allow incoming
            ufw default allow outgoing
            ufw --force enable
            show_success "Firewall dikonfigurasi untuk mengizinkan semua koneksi"
            ;;
        2)
            ufw --force reset
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow ssh
            ufw --force enable
            show_success "Firewall dikonfigurasi untuk memblokir semua koneksi masuk kecuali SSH"
            ;;
        *)
            show_error "Pilihan tidak valid"
            ;;
    esac
}

# Fungsi untuk menambah server Nginx
add_nginx_server() {
    if ! is_nginx_installed; then
        if get_confirmation "Nginx belum terinstal. Apakah Anda ingin menginstalnya?"; then
            apt update
            apt install -y nginx
            systemctl enable nginx
            systemctl start nginx
            show_success "Nginx berhasil diinstal"
        else
            show_info "Operasi dibatalkan"
            return
        fi
    fi
    
    clear_screen
    show_header "PROTOCOL-MENU/6. NETWORK/3. SERVER/1. SERVER-ADD/"
    echo ""
    
    local server_name=$(get_input "Masukkan nama server (contoh: example.com)")
    local document_root=$(get_input "Masukkan direktori root (contoh: /var/www/example.com)")
    local port=$(get_input "Masukkan port (default: 80)")
    
    if [ -z "$port" ]; then
        port="80"
    fi
    
    # Buat direktori root jika belum ada
    mkdir -p $document_root
    
    # Buat file konfigurasi virtual host
    cat > /etc/nginx/sites-available/$server_name << EOF
server {
    listen $port;
    listen [::]:$port;
    
    root $document_root;
    index index.html index.htm index.nginx-debian.html;
    
    server_name $server_name;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    
    # Aktifkan virtual host
    ln -s /etc/nginx/sites-available/$server_name /etc/nginx/sites-enabled/
    
    # Test konfigurasi Nginx
    nginx -t
    
    if [ $? -eq 0 ]; then
        systemctl reload nginx
        show_success "Server $server_name berhasil ditambahkan"
    else
        rm /etc/nginx/sites-available/$server_name
        rm /etc/nginx/sites-enabled/$server_name
        show_error "Gagal menambahkan server $server_name. Konfigurasi Nginx tidak valid"
    fi
}

# Fungsi untuk menampilkan daftar server Nginx
list_nginx_servers() {
    if ! is_nginx_installed; then
        show_error "Nginx belum terinstal"
        return
    fi
    
    clear_screen
    show_header "PROTOCOL-MENU/6. NETWORK/3. SERVER/2. SERVER-LISTS/"
    echo -e "${YELLOW}SERVER-LISTS WITH NUMBER${NC}"
    echo ""
    
    local servers=($(ls /etc/nginx/sites-available/ | grep -v "default"))
    
    for i in "${!servers[@]}"; do
        local server="${servers[$i]}"
        if is_nginx_vhost_enabled "$server"; then
            echo -e "${CYAN}$((i+1)).${NC} $server (AKTIF)"
        else
            echo -e "${CYAN}$((i+1)).${NC} $server (TIDAK AKTIF)"
        fi
    done
    
    echo ""
    local choice=$(get_input "PICK NUMBER")
    
    if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#servers[@]} ]; then
        local selected_server="${servers[$((choice-1))]}"
        
        clear_screen
        show_header "PROTOCOL-MENU/6. NETWORK/3. SERVER/2. SERVER-LISTS/"
        echo -e "${YELLOW}Server yang dipilih: $selected_server${NC}"
        echo ""
        echo -e "${CYAN}1.${NC} SERVER-SELECTED-EDIT"
        echo -e "${CYAN}2.${NC} SERVER-SELECTED-REMOVE"
        echo ""
        local action=$(get_input "Pilih aksi")
        
        case $action in
            1)
                show_info "Fitur edit server Nginx belum diimplementasikan"
                ;;
            2)
                if get_confirmation "Apakah Anda yakin ingin menghapus server $selected_server?"; then
                    rm /etc/nginx/sites-available/$selected_server
                    if is_nginx_vhost_enabled "$selected_server"; then
                        rm /etc/nginx/sites-enabled/$selected_server
                    fi
                    systemctl reload nginx
                    show_success "Server $selected_server berhasil dihapus"
                else
                    show_info "Penghapusan server dibatalkan"
                fi
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    else
        show_error "Pilihan tidak valid"
    fi
}

# Fungsi untuk menginstal RDP
install_rdp() {
    if is_rdp_installed; then
        show_info "RDP sudah terinstal"
        return
    fi
    
    show_info "Menginstal RDP..."
    apt update
    apt install -y xrdp
    
    # Tambahkan xrdp ke group ssl-cert
    adduser xrdp ssl-cert
    
    systemctl enable xrdp
    systemctl start xrdp
    
    show_success "RDP berhasil diinstal dan diaktifkan"
}

# Fungsi untuk menginstal VNC
install_vnc() {
    if is_vnc_installed; then
        show_info "VNC sudah terinstal"
        return
    fi
    
    show_info "Menginstal VNC..."
    apt update
    apt install -y tightvncserver
    
    show_success "VNC berhasil diinstal"
    show_info "Untuk menjalankan VNC server, gunakan perintah: vncserver :1 -geometry 1280x720 -depth 24"
}

# Fungsi untuk menu utama
main_menu() {
    while true; do
        clear_screen
        show_header "./PROTOCOL-MENU.SH/"
        echo -e "${CYAN}1.${NC} SHUTDOWN"
        echo -e "${CYAN}2.${NC} RESTART"
        echo -e "${CYAN}3.${NC} SYSTEM"
        echo -e "${CYAN}4.${NC} USER"
        echo -e "${CYAN}5.${NC} HARDWARE"
        echo -e "${CYAN}6.${NC} NETWORK"
        echo -e "${CYAN}X.${NC} EXIT"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                if get_confirmation "Apakah Anda yakin ingin mematikan sistem?"; then
                    shutdown now
                fi
                ;;
            2)
                if get_confirmation "Apakah Anda yakin ingin me-restart sistem?"; then
                    reboot
                fi
                ;;
            3)
                system_menu
                ;;
            4)
                user_menu
                ;;
            5)
                hardware_menu
                ;;
            6)
                network_menu
                ;;
            X|x)
                if get_confirmation "Apakah Anda yakin ingin keluar?"; then
                    exit 0
                fi
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu sistem
system_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/3. SYSTEM/"
        echo -e "${CYAN}1.${NC} CORE"
        echo -e "${CYAN}2.${NC} ADDITIONAL"
        echo -e "${CYAN}3.${NC} DEPENDENCY"
        echo -e "${CYAN}4.${NC} UTILITIES"
        echo -e "${CYAN}5.${NC} RECOVERY"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                system_core_menu
                ;;
            2)
                system_additional_menu
                ;;
            3)
                system_dependency_menu
                ;;
            4)
                system_utilities_menu
                ;;
            5)
                system_recovery_menu
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu sistem core
system_core_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/3. SYSTEM/1. CORE/"
        echo -e "${CYAN}1.${NC} UPDATE"
        echo -e "${CYAN}2.${NC} UPGRADE"
        echo -e "${CYAN}3.${NC} UPGRADE FULL"
        echo -e "${CYAN}4.${NC} UPDATE + UPGRADE"
        echo -e "${CYAN}5.${NC} UPDATE + UPGRADE FULL"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/3. SYSTEM/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                show_info "Melakukan update package list..."
                apt update
                show_success "Package list berhasil diupdate"
                ;;
            2)
                show_info "Melakukan upgrade package..."
                apt upgrade -y
                show_success "Package berhasil diupgrade"
                ;;
            3)
                show_info "Melakukan full upgrade package..."
                apt full-upgrade -y
                show_success "Package berhasil diupgrade secara penuh"
                ;;
            4)
                show_info "Melakukan update dan upgrade package..."
                apt update && apt upgrade -y
                show_success "Package berhasil diupdate dan diupgrade"
                ;;
            5)
                show_info "Melakukan update dan full upgrade package..."
                apt update && apt full-upgrade -y
                show_success "Package berhasil diupdate dan diupgrade secara penuh"
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu sistem additional
system_additional_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/3. SYSTEM/2. ADDITIONAL/"
        echo -e "${CYAN}1.${NC} UNIVERSE"
        echo -e "${CYAN}2.${NC} MULTIVERSE"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/3. SYSTEM/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                show_info "Mengaktifkan repository universe..."
                add-apt-repository universe -y
                apt update
                show_success "Repository universe berhasil diaktifkan"
                ;;
            2)
                show_info "Mengaktifkan repository multiverse..."
                add-apt-repository multiverse -y
                apt update
                show_success "Repository multiverse berhasil diaktifkan"
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu sistem dependency
system_dependency_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/3. SYSTEM/3. DEPENDENCY/"
        echo -e "${CYAN}1.${NC} BUILD-ESSENTIAL"
        echo -e "${CYAN}2.${NC} ZIP"
        echo -e "${CYAN}3.${NC} UNZIP"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/3. SYSTEM/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                show_info "Menginstal build-essential dan dependencies..."
                apt update
                apt install -y build-essential libcairo2-dev libjpeg-turbo8-dev \
                    libpng-dev libtool-bin libossp-uuid-dev libvncserver-dev \
                    freerdp2-dev libssh2-1-dev libtelnet-dev libwebsockets-dev \
                    libpulse-dev libvorbis-dev libwebp-dev libssl-dev \
                    libpango1.0-dev libswscale-dev libavcodec-dev libavutil-dev \
                    libavformat-dev \
                    librsvg2-dev \
                    libvpx-dev
                show_success "Build-essential dan dependencies berhasil diinstal"
                ;;
            2)
                show_info "Menginstal zip..."
                apt update
                apt install -y zip
                show_success "Zip berhasil diinstal"
                ;;
            3)
                show_info "Menginstal unzip..."
                apt update
                apt install -y unzip
                show_success "Unzip berhasil diinstal"
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu sistem utilities
system_utilities_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/3. SYSTEM/4. UTILITIES/"
        echo -e "${CYAN}1.${NC} APT-UTILS"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/3. SYSTEM/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                show_info "Menginstal apt-utils..."
                apt update
                apt install -y apt-utils
                show_success "Apt-utils berhasil diinstal"
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu sistem recovery
system_recovery_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/3. SYSTEM/5. RECOVERY/"
        echo -e "${CYAN}1.${NC} BACKUP"
        echo -e "${CYAN}2.${NC} RESTORE"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/3. SYSTEM/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                backup_system
                wait_enter
                ;;
            2)
                restore_system
                wait_enter
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu user
user_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/4. USER/"
        echo -e "${CYAN}1.${NC} USER-LISTS"
        echo -e "${CYAN}2.${NC} USER-ADD"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                list_users
                wait_enter
                ;;
            2)
                add_user
                wait_enter
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu hardware
hardware_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/5. HARDWARE/"
        echo -e "${CYAN}1.${NC} INFORMATION"
        echo -e "${CYAN}2.${NC} MONITORING"
        echo -e "${CYAN}3.${NC} MEMORY"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                if is_package_installed "neofetch"; then
                    neofetch
                else
                    show_info "Menginstal neofetch..."
                    apt update
                    apt install -y neofetch
                    neofetch
                fi
                wait_enter
                ;;
            2)
                if is_package_installed "htop"; then
                    htop
                else
                    show_info "Menginstal htop..."
                    apt update
                    apt install -y htop
                    htop
                fi
                ;;
            3)
                hardware_memory_menu
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu hardware memory
hardware_memory_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/5. HARDWARE/3. MEMORY/"
        echo -e "${CYAN}1.${NC} INFORMATION"
        echo -e "${CYAN}2.${NC} EXTEND"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/5. HARDWARE/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                free -h
                wait_enter
                ;;
            2)
                local size_gb=$(get_input "SIZE/ALLOCATION [__]GB")
                if [[ $size_gb =~ ^[0-9]+$ ]] && [ $size_gb -gt 0 ]; then
                    if get_confirmation "Apakah Anda yakin ingin membuat swap file sebesar ${size_gb}GB?"; then
                        create_swap $size_gb
                    else
                        show_info "Operasi dibatalkan"
                    fi
                else
                    show_error "Ukuran tidak valid"
                fi
                wait_enter
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu network
network_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/6. NETWORK/"
        echo -e "${CYAN}1.${NC} APP"
        echo -e "${CYAN}2.${NC} FIREWALL"
        echo -e "${CYAN}3.${NC} SERVER"
        echo -e "${CYAN}4.${NC} REMOTE"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                network_app_menu
                ;;
            2)
                network_firewall_menu
                ;;
            3)
                network_server_menu
                ;;
            4)
                network_remote_menu
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu network app
network_app_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/6. NETWORK/1. APP/"
        echo -e "${CYAN}1.${NC} WGET"
        echo -e "${CYAN}2.${NC} IPUTILS"
        echo -e "${CYAN}3.${NC} CURL"
        echo -e "${CYAN}4.${NC} DNSUTILS"
        echo -e "${CYAN}5.${NC} MTR"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/6. NETWORK/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                show_info "Menginstal wget..."
                apt update
                apt install -y wget
                show_success "Wget berhasil diinstal"
                ;;
            2)
                show_info "Menginstal iputils-ping..."
                apt update
                apt install -y iputils-ping
                show_success "Iputils berhasil diinstal"
                ;;
            3)
                show_info "Menginstal curl..."
                apt update
                apt install -y curl
                show_success "Curl berhasil diinstal"
                ;;
            4)
                show_info "Menginstal dnsutils..."
                apt update
                apt install -y dnsutils
                show_success "Dnsutils berhasil diinstal"
                ;;
            5)
                show_info "Menginstal mtr..."
                apt update
                apt install -y mtr
                show_success "Mtr berhasil diinstal"
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu network firewall
network_firewall_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/6. NETWORK/2. FIREWALL/"
        echo -e "${CYAN}1.${NC} FIREWALL-LISTS"
        echo -e "${CYAN}2.${NC} FIREWALL-ADD"
        echo -e "${CYAN}3.${NC} FIREWALL-AUTO"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/6. NETWORK/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                list_firewall_rules
                wait_enter
                ;;
            2)
                add_firewall_rule
                wait_enter
                ;;
            3)
                auto_firewall
                wait_enter
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu network server
network_server_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/6. NETWORK/3. SERVER/"
        echo -e "${CYAN}1.${NC} SERVER-ADD"
        echo -e "${CYAN}2.${NC} SERVER-LISTS"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                add_nginx_server
                wait_enter
                ;;
            2)
                list_nginx_servers
                wait_enter
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Fungsi untuk menu network remote
network_remote_menu() {
    while true; do
        clear_screen
        show_header "PROTOCOL-MENU/6. NETWORK/4. REMOTE/"
        echo -e "${CYAN}1.${NC} RDP"
        echo -e "${CYAN}2.${NC} VNC"
        show_footer "BACK TO ./PROTOCOL-MENU.SH/6. NETWORK/"
        
        local choice=$(get_input "Pilih menu")
        
        case $choice in
            1)
                install_rdp
                wait_enter
                ;;
            2)
                install_vnc
                wait_enter
                ;;
            *)
                show_error "Pilihan tidak valid"
                ;;
        esac
    done
}

# Cek apakah script dijalankan sebagai root
check_root

# Jalankan menu utama
main_menu
