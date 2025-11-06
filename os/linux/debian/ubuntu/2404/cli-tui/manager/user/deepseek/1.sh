#!/bin/bash

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fungsi untuk membersihkan layar
clear_screen() {
    clear
}

# Fungsi untuk menampilkan header
show_header() {
    clear_screen
    echo -e "${BLUE}"
    echo "=========================================="
    echo "     USER MANAGEMENT UBUNTU SERVER 24.04"
    echo "=========================================="
    echo -e "${NC}"
}

# Fungsi untuk menampilkan user berdasarkan tipe
show_users() {
    local user_type=$1
    
    show_header
    if [[ "$user_type" == "non-system" ]]; then
        echo -e "${GREEN}DAFTAR NON-SYSTEM USER (UID >= 1000)${NC}"
    else
        echo -e "${GREEN}DAFTAR SYSTEM USER (UID < 1000)${NC}"
    fi
    echo ""
    
    printf "%-8s %-15s %-8s %-20s %-8s %-20s %-10s\n" "NUMBER" "USERNAME" "UID" "GROUPS" "GID" "DIR" "STATUS"
    echo "---------------------------------------------------------------------------------------------------"
    
    local count=1
    while IFS=: read -r username password uid gid gecos home shell; do
        # Filter berdasarkan tipe user
        if [[ "$user_type" == "non-system" && $uid -lt 1000 ]]; then
            continue
        elif [[ "$user_type" == "system" && $uid -ge 1000 ]]; then
            continue
        fi
        
        # Dapatkan groups user
        local groups=$(id -nG "$username" 2>/dev/null | tr ' ' ',' | head -c 18)
        [[ -z "$groups" ]] && groups="N/A"
        
        # Tentukan status
        local status="INACTIVE"
        if who | grep -q "^$username "; then
            status="ACTIVE"
        elif [[ "$shell" != "/bin/false" && "$shell" != "/usr/sbin/nologin" ]]; then
            status="ACTIVE"
        fi
        
        # Potong home directory jika terlalu panjang
        local home_display="$home"
        if [[ ${#home_display} -gt 18 ]]; then
            home_display="${home:0:15}..."
        fi
        
        printf "%-8s %-15s %-8s %-20s %-8s %-20s %-10s\n" \
            "$(printf "%03d" $count)" "$username" "$uid" "$groups" "$gid" "$home_display" "$status"
        
        ((count++))
    done < /etc/passwd
}

# Fungsi untuk mendapatkan user berdasarkan nomor
get_user_by_number() {
    local user_type=$1
    local number=$2
    
    local count=1
    while IFS=: read -r username password uid gid gecos home shell; do
        # Filter berdasarkan tipe user
        if [[ "$user_type" == "non-system" && $uid -lt 1000 ]]; then
            continue
        elif [[ "$user_type" == "system" && $uid -ge 1000 ]]; then
            continue
        fi
        
        if [[ $count -eq $number ]]; then
            echo "$username"
            return
        fi
        ((count++))
    done < /etc/passwd
}

# Fungsi untuk menambah user
add_user() {
    show_header
    echo -e "${GREEN}TAMBAH USER BARU${NC}"
    echo ""
    
    read -p "Masukkan username: " username
    
    # Cek apakah user sudah ada
    if id "$username" &>/dev/null; then
        echo -e "${RED}User $username sudah ada!${NC}"
        read -p "Tekan Enter untuk melanjutkan..."
        return
    fi
    
    read -p "Masukkan password: " -s password
    echo
    read -p "Konfirmasi password: " -s password_confirm
    echo
    
    if [[ "$password" != "$password_confirm" ]]; then
        echo -e "${RED}Password tidak cocok!${NC}"
        read -p "Tekan Enter untuk melanjutkan..."
        return
    fi
    
    # Buat user
    sudo useradd -m -s /bin/bash "$username"
    echo "$username:$password" | sudo chpasswd
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}User $username berhasil dibuat!${NC}"
    else
        echo -e "${RED}Gagal membuat user $username!${NC}"
    fi
    
    read -p "Tekan Enter untuk melanjutkan..."
}

# Fungsi untuk menambah group
add_group() {
    show_header
    echo -e "${GREEN}TAMBAH GROUP BARU${NC}"
    echo ""
    
    read -p "Masukkan nama group: " groupname
    
    # Cek apakah group sudah ada
    if grep -q "^$groupname:" /etc/group; then
        echo -e "${RED}Group $groupname sudah ada!${NC}"
        read -p "Tekan Enter untuk melanjutkan..."
        return
    fi
    
    sudo groupadd "$groupname"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Group $groupname berhasil dibuat!${NC}"
    else
        echo -e "${RED}Gagal membuat group $groupname!${NC}"
    fi
    
    read -p "Tekan Enter untuk melanjutkan..."
}

# Fungsi untuk edit user
edit_user() {
    local username=$1
    
    show_header
    echo -e "${GREEN}EDIT USER: $username${NC}"
    echo ""
    
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}User $username tidak ditemukan!${NC}"
        read -p "Tekan Enter untuk melanjutkan..."
        return
    fi
    
    echo "1. Ubah username"
    echo "2. Ubah home directory"
    echo "3. Ubah shell"
    echo "4. Tambah ke group"
    echo "5. Keluar dari group"
    echo "6. Kembali"
    
    read -p "Pilihan [1-6]: " choice
    
    case $choice in
        1)
            read -p "Masukkan username baru: " new_username
            sudo usermod -l "$new_username" "$username"
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Username berhasil diubah!${NC}"
            else
                echo -e "${RED}Gagal mengubah username!${NC}"
            fi
            ;;
        2)
            read -p "Masukkan home directory baru: " new_home
            sudo usermod -d "$new_home" -m "$username"
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Home directory berhasil diubah!${NC}"
            else
                echo -e "${RED}Gagal mengubah home directory!${NC}"
            fi
            ;;
        3)
            echo "Shell yang tersedia:"
            echo "/bin/bash, /bin/sh, /bin/zsh, /usr/sbin/nologin, /bin/false"
            read -p "Masukkan shell baru: " new_shell
            sudo usermod -s "$new_shell" "$username"
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Shell berhasil diubah!${NC}"
            else
                echo -e "${RED}Gagal mengubah shell!${NC}"
            fi
            ;;
        4)
            read -p "Masukkan nama group: " groupname
            sudo usermod -aG "$groupname" "$username"
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}User berhasil ditambahkan ke group $groupname!${NC}"
            else
                echo -e "${RED}Gagal menambahkan user ke group!${NC}"
            fi
            ;;
        5)
            read -p "Masukkan nama group: " groupname
            sudo gpasswd -d "$username" "$groupname"
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}User berhasil dikeluarkan dari group $groupname!${NC}"
            else
                echo -e "${RED}Gagal mengeluarkan user dari group!${NC}"
            fi
            ;;
        6)
            return
            ;;
        *)
            echo -e "${RED}Pilihan tidak valid!${NC}"
            ;;
    esac
    
    read -p "Tekan Enter untuk melanjutkan..."
}

# Fungsi untuk reset password
reset_password() {
    local username=$1
    
    show_header
    echo -e "${GREEN}RESET PASSWORD: $username${NC}"
    echo ""
    
    read -p "Masukkan password baru: " -s new_password
    echo
    read -p "Konfirmasi password baru: " -s confirm_password
    echo
    
    if [[ "$new_password" != "$confirm_password" ]]; then
        echo -e "${RED}Password tidak cocok!${NC}"
    else
        echo "$username:$new_password" | sudo chpasswd
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Password berhasil direset!${NC}"
        else
            echo -e "${RED}Gagal reset password!${NC}"
        fi
    fi
    
    read -p "Tekan Enter untuk melanjutkan..."
}

# Fungsi untuk delete user
delete_user() {
    local username=$1
    
    show_header
    echo -e "${GREEN}DELETE USER: $username${NC}"
    echo ""
    
    read -p "Apakah Anda yakin ingin menghapus user $username? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Pilih opsi delete:"
        echo "1. Hapus user saja"
        echo "2. Hapus user beserta home directory"
        echo "3. Batal"
        
        read -p "Pilihan [1-3]: " delete_choice
        
        case $delete_choice in
            1)
                sudo userdel "$username"
                ;;
            2)
                sudo userdel -r "$username"
                ;;
            3)
                echo "Penghapusan dibatalkan"
                return
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid!${NC}"
                return
                ;;
        esac
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}User $username berhasil dihapus!${NC}"
        else
            echo -e "${RED}Gagal menghapus user!${NC}"
        fi
    else
        echo "Penghapusan dibatalkan"
    fi
    
    read -p "Tekan Enter untuk melanjutkan..."
}

# Fungsi untuk melihat user
view_users() {
    while true; do
        show_header
        echo -e "${GREEN}LIHAT USER${NC}"
        echo ""
        echo "1. NON-SYSTEM USER"
        echo "2. SYSTEM USER" 
        echo "3. KEMBALI"
        echo ""
        
        read -p "Pilihan [1-3]: " view_choice
        
        case $view_choice in
            1)
                show_users "non-system"
                handle_user_selection "non-system"
                ;;
            2)
                show_users "system" 
                handle_user_selection "system"
                ;;
            3)
                return
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid!${NC}"
                read -p "Tekan Enter untuk melanjutkan..."
                ;;
        esac
    done
}

# Fungsi untuk menangani pemilihan user
handle_user_selection() {
    local user_type=$1
    
    echo ""
    read -p "Masukkan NUMBER user: " user_number
    
    if [[ ! "$user_number" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Input harus angka!${NC}"
        read -p "Tekan Enter untuk melanjutkan..."
        return
    fi
    
    local username=$(get_user_by_number "$user_type" "$user_number")
    
    if [[ -z "$username" ]]; then
        echo -e "${RED}User tidak ditemukan!${NC}"
        read -p "Tekan Enter untuk melanjutkan..."
        return
    fi
    
    # Tampilkan menu aksi untuk user
    while true; do
        show_header
        echo -e "${GREEN}USER: $username${NC}"
        echo ""
        echo "1. EDIT"
        echo "2. RESET PASSWORD"
        echo "3. DELETE"
        echo "4. KEMBALI"
        echo ""
        
        read -p "Pilihan [1-4]: " action_choice
        
        case $action_choice in
            1)
                edit_user "$username"
                ;;
            2)
                reset_password "$username"
                ;;
            3)
                delete_user "$username"
                # Jika user dihapus, keluar dari loop
                if ! id "$username" &>/dev/null; then
                    read -p "Tekan Enter untuk melanjutkan..."
                    return
                fi
                ;;
            4)
                return
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid!${NC}"
                read -p "Tekan Enter untuk melanjutkan..."
                ;;
        esac
    done
}

# Fungsi utama
main() {
    while true; do
        show_header
        echo -e "${GREEN}MENU UTAMA${NC}"
        echo ""
        echo "1. LIHAT SEMUA USER"
        echo "2. TAMBAH USER"
        echo "3. TAMBAH GROUP"
        echo "4. KELUAR"
        echo ""
        
        read -p "Pilihan [1-4]: " main_choice
        
        case $main_choice in
            1)
                view_users
                ;;
            2)
                add_user
                ;;
            3)
                add_group
                ;;
            4)
                echo -e "${GREEN}Terima kasih!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid!${NC}"
                read -p "Tekan Enter untuk melanjutkan..."
                ;;
        esac
    done
}

# Jalankan fungsi utama
main "$@"
