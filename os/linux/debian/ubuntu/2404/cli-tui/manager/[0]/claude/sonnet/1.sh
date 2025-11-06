#!/bin/bash

#=============================================================================
# PROTOCOL-MENU.SH - Ubuntu 24.04 System Management Script
# Version: 1.0
# Description: Comprehensive system management menu with backup, user, 
#              hardware, and network management capabilities
#=============================================================================

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
LOG_DIR="/var/log/protocol-menu"
LOG_FILE="$LOG_DIR/protocol-menu-$(date +%Y-%m-%d).log"
BACKUP_DIR="/var/backups/protocol-backup"

#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}ERROR: This script must be run as root (sudo)${NC}"
        exit 1
    fi
}

# Initialize log directory
init_log() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
}

# Log function
log_action() {
    local action="$1"
    local status="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [USER: $SUDO_USER] [ACTION: $action] [STATUS: $status]" >> "$LOG_FILE"
}

# Pause function
pause() {
    echo ""
    read -p "Press any key to continue..."
}

# Clear screen and show header
show_header() {
    clear
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}         PROTOCOL-MENU - Ubuntu 24.04 Management${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
}

# Check and install dependency
check_install_dependency() {
    local package="$1"
    local description="$2"
    
    if ! command -v "$package" &> /dev/null; then
        echo -e "${YELLOW}$description ($package) is not installed.${NC}"
        read -p "Do you want to install it now? (y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            apt update
            apt install -y "$package"
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}$package installed successfully.${NC}"
                log_action "Install $package" "SUCCESS"
                return 0
            else
                echo -e "${RED}Failed to install $package.${NC}"
                log_action "Install $package" "FAILED"
                return 1
            fi
        else
            echo -e "${YELLOW}Skipping installation.${NC}"
            return 1
        fi
    fi
    return 0
}

#=============================================================================
# MAIN MENU
#=============================================================================

main_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[------------------------------------------------------------]${NC}"
        echo -e "${GREEN}  MAIN MENU${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  0. LOG"
        echo "  1. SHUTDOWN"
        echo "  2. RESTART"
        echo "  3. SYSTEM"
        echo "  4. USER"
        echo "  5. HARDWARE"
        echo "  6. NETWORK"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  X. EXIT"
        echo -e "${BLUE}[------------------------------------------------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            0) log_menu ;;
            1) shutdown_system ;;
            2) restart_system ;;
            3) system_menu ;;
            4) user_menu ;;
            5) hardware_menu ;;
            6) network_menu ;;
            x|X) exit_script ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

#=============================================================================
# 0. LOG MENU
#=============================================================================

log_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  LOG SYSTEM${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. View Last 100 Lines"
        echo "  2. View Full Log"
        echo "  3. Clear Log"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to Main Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) 
                show_header
                echo -e "${GREEN}Last 100 log entries:${NC}"
                echo ""
                tail -n 100 "$LOG_FILE"
                pause
                ;;
            2)
                show_header
                echo -e "${GREEN}Full log:${NC}"
                echo ""
                less "$LOG_FILE"
                ;;
            3)
                read -p "Are you sure you want to clear the log? (y/n): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    > "$LOG_FILE"
                    echo -e "${GREEN}Log cleared successfully.${NC}"
                    log_action "Clear Log" "SUCCESS"
                fi
                pause
                ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

#=============================================================================
# 1. SHUTDOWN
#=============================================================================

shutdown_system() {
    show_header
    echo -e "${YELLOW}WARNING: This will shutdown the system!${NC}"
    read -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        log_action "System Shutdown" "INITIATED"
        shutdown now
    fi
}

#=============================================================================
# 2. RESTART
#=============================================================================

restart_system() {
    show_header
    echo -e "${YELLOW}WARNING: This will restart the system!${NC}"
    read -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        log_action "System Restart" "INITIATED"
        reboot
    fi
}

#=============================================================================
# 3. SYSTEM MENU
#=============================================================================

system_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  SYSTEM MENU${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. CORE"
        echo "  2. ADDITIONAL"
        echo "  3. DEPENDENCY"
        echo "  4. UTILITIES"
        echo "  5. RECOVERY"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to Main Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) system_core_menu ;;
            2) system_additional_menu ;;
            3) system_dependency_menu ;;
            4) system_utilities_menu ;;
            5) system_recovery_menu ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

# 3.1 CORE
system_core_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  SYSTEM > CORE${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. UPDATE"
        echo "  2. UPGRADE"
        echo "  3. UPGRADE FULL"
        echo "  4. UPDATE + UPGRADE"
        echo "  5. UPDATE + UPGRADE FULL"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to System Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                show_header
                echo -e "${GREEN}Running apt update...${NC}"
                apt update
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Update completed successfully.${NC}"
                    log_action "APT Update" "SUCCESS"
                else
                    echo -e "${RED}Update failed.${NC}"
                    log_action "APT Update" "FAILED"
                fi
                pause
                ;;
            2)
                show_header
                echo -e "${GREEN}Running apt upgrade...${NC}"
                apt upgrade -y
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Upgrade completed successfully.${NC}"
                    log_action "APT Upgrade" "SUCCESS"
                else
                    echo -e "${RED}Upgrade failed.${NC}"
                    log_action "APT Upgrade" "FAILED"
                fi
                pause
                ;;
            3)
                show_header
                echo -e "${GREEN}Running apt full-upgrade...${NC}"
                apt full-upgrade -y
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Full upgrade completed successfully.${NC}"
                    log_action "APT Full Upgrade" "SUCCESS"
                else
                    echo -e "${RED}Full upgrade failed.${NC}"
                    log_action "APT Full Upgrade" "FAILED"
                fi
                pause
                ;;
            4)
                show_header
                echo -e "${GREEN}Running apt update && upgrade...${NC}"
                apt update && apt upgrade -y
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Update + Upgrade completed successfully.${NC}"
                    log_action "APT Update + Upgrade" "SUCCESS"
                else
                    echo -e "${RED}Update + Upgrade failed.${NC}"
                    log_action "APT Update + Upgrade" "FAILED"
                fi
                pause
                ;;
            5)
                show_header
                echo -e "${GREEN}Running apt update && full-upgrade...${NC}"
                apt update && apt full-upgrade -y
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Update + Full Upgrade completed successfully.${NC}"
                    log_action "APT Update + Full Upgrade" "SUCCESS"
                else
                    echo -e "${RED}Update + Full Upgrade failed.${NC}"
                    log_action "APT Update + Full Upgrade" "FAILED"
                fi
                pause
                ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

# 3.2 ADDITIONAL
system_additional_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  SYSTEM > ADDITIONAL${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. UNIVERSE"
        echo "  2. MULTIVERSE"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to System Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                show_header
                echo -e "${GREEN}Enabling Universe repository...${NC}"
                add-apt-repository universe -y
                apt update
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Universe repository enabled successfully.${NC}"
                    log_action "Enable Universe Repository" "SUCCESS"
                else
                    echo -e "${RED}Failed to enable Universe repository.${NC}"
                    log_action "Enable Universe Repository" "FAILED"
                fi
                pause
                ;;
            2)
                show_header
                echo -e "${GREEN}Enabling Multiverse repository...${NC}"
                add-apt-repository multiverse -y
                apt update
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Multiverse repository enabled successfully.${NC}"
                    log_action "Enable Multiverse Repository" "SUCCESS"
                else
                    echo -e "${RED}Failed to enable Multiverse repository.${NC}"
                    log_action "Enable Multiverse Repository" "FAILED"
                fi
                pause
                ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

# 3.3 DEPENDENCY
system_dependency_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  SYSTEM > DEPENDENCY${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. BUILD-ESSENTIAL"
        echo "  2. ZIP"
        echo "  3. UNZIP"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to System Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                show_header
                echo -e "${GREEN}Installing build-essential and development libraries...${NC}"
                apt install -y build-essential libcairo2-dev libjpeg-turbo8-dev \
                    libpng-dev libtool-bin libossp-uuid-dev libvncserver-dev \
                    freerdp2-dev libssh2-1-dev libtelnet-dev libwebsockets-dev \
                    libpulse-dev libvorbis-dev libwebp-dev libssl-dev \
                    libpango1.0-dev libswscale-dev libavcodec-dev libavutil-dev \
                    libavformat-dev librsvg2-dev libvpx-dev
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Build-essential installed successfully.${NC}"
                    log_action "Install Build-Essential" "SUCCESS"
                else
                    echo -e "${RED}Failed to install build-essential.${NC}"
                    log_action "Install Build-Essential" "FAILED"
                fi
                pause
                ;;
            2)
                show_header
                echo -e "${GREEN}Installing zip...${NC}"
                apt install -y zip
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Zip installed successfully.${NC}"
                    log_action "Install Zip" "SUCCESS"
                else
                    echo -e "${RED}Failed to install zip.${NC}"
                    log_action "Install Zip" "FAILED"
                fi
                pause
                ;;
            3)
                show_header
                echo -e "${GREEN}Installing unzip...${NC}"
                apt install -y unzip
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Unzip installed successfully.${NC}"
                    log_action "Install Unzip" "SUCCESS"
                else
                    echo -e "${RED}Failed to install unzip.${NC}"
                    log_action "Install Unzip" "FAILED"
                fi
                pause
                ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

# 3.4 UTILITIES
system_utilities_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  SYSTEM > UTILITIES${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. APT-UTILS"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to System Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                show_header
                echo -e "${GREEN}Installing apt-utils...${NC}"
                apt install -y apt-utils
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Apt-utils installed successfully.${NC}"
                    log_action "Install Apt-Utils" "SUCCESS"
                else
                    echo -e "${RED}Failed to install apt-utils.${NC}"
                    log_action "Install Apt-Utils" "FAILED"
                fi
                pause
                ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

# 3.5 RECOVERY
system_recovery_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  SYSTEM > RECOVERY${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. BACKUP"
        echo "  2. RESTORE"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to System Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) system_backup ;;
            2) system_restore ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

# 3.5.1 BACKUP
system_backup() {
    show_header
    echo -e "${GREEN}=== SYSTEM BACKUP ===${NC}"
    echo ""
    echo "This will backup:"
    echo "  - Installed packages list"
    echo "  - /etc configuration files"
    echo "  - User home directories"
    echo ""
    
    mkdir -p "$BACKUP_DIR"
    
    BACKUP_NAME="backup-$(date +%Y-%m-%d-%H%M%S)"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
    
    echo -e "${YELLOW}Backup will be saved to: $BACKUP_PATH.tar.gz${NC}"
    read -p "Continue with backup? (y/n): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Backup cancelled."
        pause
        return
    fi
    
    echo ""
    echo -e "${GREEN}Starting backup process...${NC}"
    
    # Create temporary directory
    mkdir -p "$BACKUP_PATH"
    
    # Backup package list
    echo "Backing up package list..."
    dpkg --get-selections > "$BACKUP_PATH/packages.list"
    
    # Backup /etc
    echo "Backing up /etc configuration..."
    tar -czf "$BACKUP_PATH/etc-backup.tar.gz" /etc 2>/dev/null
    
    # Backup user homes
    echo "Backing up user home directories..."
    tar -czf "$BACKUP_PATH/home-backup.tar.gz" /home 2>/dev/null
    
    # Create final compressed backup
    echo "Creating final backup archive..."
    cd "$BACKUP_DIR"
    tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME/"
    rm -rf "$BACKUP_NAME"
    
    if [[ $? -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}Backup completed successfully!${NC}"
        echo -e "Backup location: ${CYAN}$BACKUP_PATH.tar.gz${NC}"
        echo -e "Backup size: $(du -h "$BACKUP_PATH.tar.gz" | cut -f1)"
        log_action "System Backup" "SUCCESS - $BACKUP_NAME"
    else
        echo -e "${RED}Backup failed!${NC}"
        log_action "System Backup" "FAILED"
    fi
    
    pause
}

# 3.5.2 RESTORE
system_restore() {
    show_header
    echo -e "${GREEN}=== SYSTEM RESTORE ===${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR/*.tar.gz 2>/dev/null)" ]; then
        echo -e "${RED}No backups found in $BACKUP_DIR${NC}"
        pause
        return
    fi
    
    echo "Available backups:"
    echo ""
    
    backups=($(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
    
    for i in "${!backups[@]}"; do
        backup_file="${backups[$i]}"
        backup_name=$(basename "$backup_file")
        backup_size=$(du -h "$backup_file" | cut -f1)
        echo "  $((i+1)). $backup_name ($backup_size)"
    done
    
    echo ""
    read -p "Select backup number to restore (or 'b' to go back): " choice
    
    if [[ "$choice" == "b" || "$choice" == "B" ]]; then
        return
    fi
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#backups[@]}" ]; then
        echo -e "${RED}Invalid selection${NC}"
        pause
        return
    fi
    
    selected_backup="${backups[$((choice-1))]}"
    
    echo ""
    echo -e "${YELLOW}WARNING: This will restore system files from backup!${NC}"
    echo -e "Selected backup: ${CYAN}$(basename "$selected_backup")${NC}"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Restore cancelled."
        pause
        return
    fi
    
    echo ""
    echo -e "${GREEN}Starting restore process...${NC}"
    
    # Extract backup
    RESTORE_DIR="/tmp/protocol-restore-$$"
    mkdir -p "$RESTORE_DIR"
    
    echo "Extracting backup..."
    tar -xzf "$selected_backup" -C "$RESTORE_DIR"
    
    BACKUP_CONTENT="$RESTORE_DIR/$(basename "$selected_backup" .tar.gz)"
    
    # Restore packages
    if [ -f "$BACKUP_CONTENT/packages.list" ]; then
        echo "Restoring packages..."
        dpkg --set-selections < "$BACKUP_CONTENT/packages.list"
        apt-get dselect-upgrade -y
    fi
    
    # Restore /etc
    if [ -f "$BACKUP_CONTENT/etc-backup.tar.gz" ]; then
        echo "Restoring /etc configuration..."
        tar -xzf "$BACKUP_CONTENT/etc-backup.tar.gz" -C /
    fi
    
    # Restore home
    if [ -f "$BACKUP_CONTENT/home-backup.tar.gz" ]; then
        echo "Restoring home directories..."
        tar -xzf "$BACKUP_CONTENT/home-backup.tar.gz" -C /
    fi
    
    # Cleanup
    rm -rf "$RESTORE_DIR"
    
    if [[ $? -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}Restore completed successfully!${NC}"
        echo -e "${YELLOW}Please reboot the system for changes to take effect.${NC}"
        log_action "System Restore" "SUCCESS - $(basename "$selected_backup")"
    else
        echo -e "${RED}Restore failed!${NC}"
        log_action "System Restore" "FAILED"
    fi
    
    pause
}

#=============================================================================
# 4. USER MENU
#=============================================================================

user_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  USER MENU${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. USER-LISTS"
        echo "  2. USER-ADD"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to Main Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) user_lists ;;
            2) user_add ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

# 4.2 USER-ADD
user_add() {
    show_header
    echo -e "${GREEN}=== ADD NEW USER ===${NC}"
    echo ""
    
    read -p "Enter new username: " username
    
    if id "$username" &>/dev/null; then
        echo -e "${RED}User '$username' already exists!${NC}"
        pause
        return
    fi
    
    read -s -p "Enter password: " password
    echo ""
    read -s -p "Confirm password: " password2
    echo ""
    
    if [ "$password" != "$password2" ]; then
        echo -e "${RED}Passwords do not match!${NC}"
        pause
        return
    fi
    
    echo ""
    echo "User access level:"
    echo "  1. ROOT (sudo access)"
    echo "  2. NON-ROOT (regular user)"
    read -p "Select access level: " access
    
    # Create user
    useradd -m -s /bin/bash "$username"
    echo "$username:$password" | chpasswd
    
    if [ "$access" == "1" ]; then
        usermod -aG sudo "$username"
        echo -e "${GREEN}User '$username' created with sudo access.${NC}"
        log_action "User Add" "SUCCESS - $username (sudo)"
    else
        echo -e "${GREEN}User '$username' created as regular user.${NC}"
        log_action "User Add" "SUCCESS - $username (regular)"
    fi
    
    pause
}

# 4.1 USER-LISTS
user_lists() {
    while true; do
        show_header
        echo -e "${GREEN}=== USER LIST ===${NC}"
        echo ""
        
        # Get non-system users (UID >= 1000)
        users=($(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd))
        
        if [ ${#users[@]} -eq 0 ]; then
            echo -e "${YELLOW}No regular users found.${NC}"
            pause
            return
        fi
        
        for i in "${!users[@]}"; do
            user="${users[$i]}"
            if groups "$user" | grep -q sudo; then
                access="${GREEN}[SUDO]${NC}"
            else
                access="${YELLOW}[USER]${NC}"
            fi
            echo -e "  $((i+1)). $user $access"
        done
        
        echo ""
        read -p "Select user number (or 'b' to go back): " choice
        
        if [[ "$choice" == "b" || "$choice" == "B" ]]; then
            return
        fi
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#users[@]}" ]; then
            echo -e "${RED}Invalid selection${NC}"
            pause
            continue
        fi
        
        selected_user="${users[$((choice-1))]}"
        user_edit_menu "$selected_user"
    done
}

user_edit_menu() {
    local username="$1"
    
    while true; do
        show_header
        echo -e "${GREEN}=== EDIT USER: $username ===${NC}"
        echo ""
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. EDIT NAME"
        echo "  2. EDIT PASSWORD"
        echo "  3. EDIT ACCESS"
        echo "  4. REMOVE USER"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to User List"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) user_edit_name "$username"; return ;;
            2) user_edit_password "$username" ;;
            3) user_edit_access "$username" ;;
            4) user_remove "$username"; return ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

user_edit_name() {
    local old_username="$1"
    
    show_header
    echo -e "${YELLOW}WARNING: Renaming a user is a complex operation!${NC}"
    echo -e "${YELLOW}The user must be logged out and all processes will be killed.${NC}"
    echo ""
    echo -e "${RED}IMPORTANT: This will DELETE the user and all their files!${NC}"
    echo -e "${RED}Make sure to backup important data first.${NC}"
    echo ""
    read -p "Are you sure you want to delete user '$old_username'? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Operation cancelled."
        pause
        return
    fi
    
    # Kill user processes
    pkill -u "$old_username"
    sleep 2
    
    # Delete user and home directory
    userdel -r "$old_username"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}User '$old_username' deleted successfully.${NC}"
        log_action "User Delete" "SUCCESS - $old_username"
    else
        echo -e "${RED}Failed to delete user.${NC}"
        log_action "User Delete" "FAILED - $old_username"
    fi
    
    pause
}

user_edit_password() {
    local username="$1"
    
    show_header
    echo -e "${GREEN}=== CHANGE PASSWORD FOR: $username ===${NC}"
    echo ""
    
    read -s -p "Enter new password: " password
    echo ""
    read -s -p "Confirm new password: " password2
    echo ""
    
    if [ "$password" != "$password2" ]; then
        echo -e "${RED}Passwords do not match!${NC}"
        pause
        return
    fi
    
    echo "$username:$password" | chpasswd
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Password changed successfully.${NC}"
        log_action "User Password Change" "SUCCESS - $username"
    else
        echo -e "${RED}Failed to change password.${NC}"
        log_action "User Password Change" "FAILED - $username"
    fi
    
    pause
}

user_edit_access() {
    local username="$1"
    
    show_header
    echo -e "${GREEN}=== CHANGE ACCESS FOR: $username ===${NC}"
    echo ""
    echo "Select new access level:"
    echo "  1. ROOT (sudo access)"
    echo "  2. NON-ROOT (regular user)"
    read -p "Select access level: " access
    
    if [ "$access" == "1" ]; then
        usermod -aG sudo "$username"
        echo -e "${GREEN}User '$username' granted sudo access.${NC}"
        log_action "User Access Change" "SUCCESS - $username (sudo)"
    elif [ "$access" == "2" ]; then
        gpasswd -d "$username" sudo
        echo -e "${GREEN}User '$username' sudo access removed.${NC}"
        log_action "User Access Change" "SUCCESS - $username (regular)"
    else
        echo -e "${RED}Invalid option${NC}"
    fi
    
    pause
}

user_remove() {
    local username="$1"
    
    show_header
    echo -e "${RED}WARNING: This will delete the user and their home directory!${NC}"
    echo -e "User to delete: ${YELLOW}$username${NC}"
    echo ""
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Operation cancelled."
        pause
        return
    fi
    
    # Kill user processes
    pkill -u "$username"
    sleep 2
    
    # Delete user and home directory
    userdel -r "$username"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}User '$username' deleted successfully.${NC}"
        log_action "User Remove" "SUCCESS - $username"
    else
        echo -e "${RED}Failed to delete user.${NC}"
        log_action "User Remove" "FAILED - $username"
    fi
    
    pause
}

#=============================================================================
# 5. HARDWARE MENU
#=============================================================================

hardware_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  HARDWARE MENU${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. INFORMATION"
        echo "  2. MONITORING"
        echo "  3. MEMORY"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to Main Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) hardware_information ;;
            2) hardware_monitoring ;;
            3) hardware_memory_menu ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

# 5.1 INFORMATION
hardware_information() {
    if check_install_dependency "neofetch" "Neofetch"; then
        show_header
        neofetch
        log_action "Hardware Information" "VIEWED"
        pause
    else
        pause
    fi
}

# 5.2 MONITORING
hardware_monitoring() {
    if check_install_dependency "htop" "Htop"; then
        log_action "Hardware Monitoring" "STARTED"
        htop
    else
        pause
    fi
}

# 5.3 MEMORY
hardware_memory_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  HARDWARE > MEMORY${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. INFORMATION"
        echo "  2. EXTEND (SWAP)"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to Hardware Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) memory_information ;;
            2) memory_extend ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

memory_information() {
    show_header
    echo -e "${GREEN}=== MEMORY INFORMATION ===${NC}"
    echo ""
    free -h
    echo ""
    echo -e "${CYAN}=== SWAP DETAILS ===${NC}"
    swapon --show
    log_action "Memory Information" "VIEWED"
    pause
}

memory_extend() {
    show_header
    echo -e "${GREEN}=== EXTEND MEMORY (SWAP) ===${NC}"
    echo ""
    
    # Check existing swap
    existing_swap=$(swapon --show=NAME --noheadings)
    
    if [ ! -z "$existing_swap" ]; then
        echo -e "${YELLOW}Existing swap detected:${NC}"
        swapon --show
        echo ""
        read -p "Do you want to remove existing swap first? (y/n): " remove_swap
        
        if [[ "$remove_swap" == "y" || "$remove_swap" == "Y" ]]; then
            for swap in $existing_swap; do
                swapoff "$swap"
                if [ -f "$swap" ]; then
                    rm -f "$swap"
                fi
            done
            echo -e "${GREEN}Existing swap removed.${NC}"
            # Remove from fstab
            sed -i '/swap/d' /etc/fstab
        else
            echo "Keeping existing swap. You can have multiple swap files."
        fi
        echo ""
    fi
    
    read -p "Enter swap size in GB: " swap_size
    
    if ! [[ "$swap_size" =~ ^[0-9]+$ ]] || [ "$swap_size" -lt 1 ]; then
        echo -e "${RED}Invalid size. Must be a positive number.${NC}"
        pause
        return
    fi
    
    SWAP_FILE="/swapfile-${swap_size}G"
    
    echo ""
    echo -e "${CYAN}Swap configuration:${NC}"
    echo "  Location: $SWAP_FILE"
    echo "  Size: ${swap_size}GB"
    echo ""
    read -p "Continue with swap creation? (y/n): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Swap creation cancelled."
        pause
        return
    fi
    
    echo ""
    echo -e "${GREEN}Creating swap file...${NC}"
    
    # Create swap file
    dd if=/dev/zero of="$SWAP_FILE" bs=1G count="$swap_size" status=progress
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE"
    swapon "$SWAP_FILE"
    
    # Add to fstab
    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    fi
    
    if [[ $? -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}Swap created successfully!${NC}"
        echo ""
        swapon --show
        log_action "Swap Create" "SUCCESS - ${swap_size}GB"
    else
        echo -e "${RED}Failed to create swap.${NC}"
        log_action "Swap Create" "FAILED"
    fi
    
    pause
}

#=============================================================================
# 6. NETWORK MENU
#=============================================================================

network_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  NETWORK MENU${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. APP"
        echo "  2. FIREWALL"
        echo "  3. SERVER"
        echo "  4. REMOTE (Not Available)"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to Main Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) network_app_menu ;;
            2) network_firewall_menu ;;
            3) network_server_menu ;;
            4) echo -e "${YELLOW}Remote feature is not available yet.${NC}"; pause ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

# 6.1 APP
network_app_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  NETWORK > APP${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. WGET"
        echo "  2. IPUTILS"
        echo "  3. CURL"
        echo "  4. DNSUTILS"
        echo "  5. MTR"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to Network Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                show_header
                echo -e "${GREEN}Installing wget...${NC}"
                apt install -y wget
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Wget installed successfully.${NC}"
                    log_action "Install Wget" "SUCCESS"
                else
                    echo -e "${RED}Failed to install wget.${NC}"
                    log_action "Install Wget" "FAILED"
                fi
                pause
                ;;
            2)
                show_header
                echo -e "${GREEN}Installing iputils...${NC}"
                apt install -y iputils-ping iputils-tracepath
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Iputils installed successfully.${NC}"
                    log_action "Install Iputils" "SUCCESS"
                else
                    echo -e "${RED}Failed to install iputils.${NC}"
                    log_action "Install Iputils" "FAILED"
                fi
                pause
                ;;
            3)
                show_header
                echo -e "${GREEN}Installing curl...${NC}"
                apt install -y curl
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Curl installed successfully.${NC}"
                    log_action "Install Curl" "SUCCESS"
                else
                    echo -e "${RED}Failed to install curl.${NC}"
                    log_action "Install Curl" "FAILED"
                fi
                pause
                ;;
            4)
                show_header
                echo -e "${GREEN}Installing dnsutils...${NC}"
                apt install -y dnsutils
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Dnsutils installed successfully.${NC}"
                    log_action "Install Dnsutils" "SUCCESS"
                else
                    echo -e "${RED}Failed to install dnsutils.${NC}"
                    log_action "Install Dnsutils" "FAILED"
                fi
                pause
                ;;
            5)
                show_header
                echo -e "${GREEN}Installing mtr...${NC}"
                apt install -y mtr
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}MTR installed successfully.${NC}"
                    log_action "Install MTR" "SUCCESS"
                else
                    echo -e "${RED}Failed to install mtr.${NC}"
                    log_action "Install MTR" "FAILED"
                fi
                pause
                ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

# 6.2 FIREWALL
network_firewall_menu() {
    # Check if UFW is installed
    if ! command -v ufw &> /dev/null; then
        show_header
        echo -e "${YELLOW}UFW (Uncomplicated Firewall) is not installed.${NC}"
        read -p "Do you want to install it now? (y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            apt update
            apt install -y ufw
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}UFW installed successfully.${NC}"
                log_action "Install UFW" "SUCCESS"
            else
                echo -e "${RED}Failed to install UFW.${NC}"
                log_action "Install UFW" "FAILED"
                pause
                return
            fi
        else
            return
        fi
    fi
    
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  NETWORK > FIREWALL${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. FIREWALL-LISTS"
        echo "  2. FIREWALL-ADD"
        echo "  3. FIREWALL-AUTO"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to Network Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) firewall_lists ;;
            2) firewall_add ;;
            3) firewall_auto_menu ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

firewall_lists() {
    while true; do
        show_header
        echo -e "${GREEN}=== FIREWALL RULES ===${NC}"
        echo ""
        
        # Get UFW status
        ufw status numbered
        
        echo ""
        read -p "Enter rule number to edit/delete (or 'b' to go back): " choice
        
        if [[ "$choice" == "b" || "$choice" == "B" ]]; then
            return
        fi
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid selection${NC}"
            pause
            continue
        fi
        
        firewall_edit_menu "$choice"
    done
}

firewall_edit_menu() {
    local rule_num="$1"
    
    show_header
    echo -e "${GREEN}=== FIREWALL RULE #$rule_num ===${NC}"
    echo ""
    echo -e "${BLUE}[--------------------]${NC}"
    echo "  1. DELETE RULE"
    echo -e "${BLUE}[-------------------->]${NC}"
    echo "  B. Back to Firewall List"
    echo -e "${BLUE}[--------------------]${NC}"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1)
            read -p "Are you sure you want to delete rule #$rule_num? (y/n): " confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                ufw delete "$rule_num"
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}Rule deleted successfully.${NC}"
                    log_action "Firewall Delete Rule" "SUCCESS - Rule #$rule_num"
                else
                    echo -e "${RED}Failed to delete rule.${NC}"
                    log_action "Firewall Delete Rule" "FAILED"
                fi
                pause
            fi
            ;;
        b|B) return ;;
        *) echo -e "${RED}Invalid option${NC}"; pause ;;
    esac
}

firewall_add() {
    show_header
    echo -e "${GREEN}=== ADD FIREWALL RULE ===${NC}"
    echo ""
    echo "Select rule type:"
    echo "  1. Add by Port (e.g., 8080/tcp)"
    echo "  2. Add by Service (e.g., ssh, http, https)"
    echo "  3. Add by IP Range (e.g., from 192.168.1.0/24)"
    echo ""
    read -p "Select option: " rule_type
    
    case $rule_type in
        1)
            read -p "Enter port and protocol (e.g., 8080/tcp): " port
            ufw allow "$port"
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Port rule added successfully.${NC}"
                log_action "Firewall Add Port" "SUCCESS - $port"
            else
                echo -e "${RED}Failed to add port rule.${NC}"
                log_action "Firewall Add Port" "FAILED"
            fi
            ;;
        2)
            read -p "Enter service name (e.g., ssh, http, https): " service
            ufw allow "$service"
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Service rule added successfully.${NC}"
                log_action "Firewall Add Service" "SUCCESS - $service"
            else
                echo -e "${RED}Failed to add service rule.${NC}"
                log_action "Firewall Add Service" "FAILED"
            fi
            ;;
        3)
            read -p "Enter IP range (e.g., 192.168.1.0/24): " ip_range
            ufw allow from "$ip_range"
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}IP range rule added successfully.${NC}"
                log_action "Firewall Add IP Range" "SUCCESS - $ip_range"
            else
                echo -e "${RED}Failed to add IP range rule.${NC}"
                log_action "Firewall Add IP Range" "FAILED"
            fi
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    pause
}

firewall_auto_menu() {
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  FIREWALL > AUTO${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. FIREWALL-ALL-ALLOW"
        echo "  2. FIREWALL-ALL-DISALLOW"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to Firewall Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                show_header
                echo -e "${YELLOW}WARNING: This will allow ALL incoming traffic!${NC}"
                read -p "Are you sure? (yes/no): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    ufw default allow incoming
                    ufw --force enable
                    echo -e "${GREEN}All incoming traffic allowed.${NC}"
                    log_action "Firewall Allow All" "SUCCESS"
                fi
                pause
                ;;
            2)
                show_header
                echo -e "${YELLOW}WARNING: This will deny ALL incoming traffic!${NC}"
                echo -e "${RED}Make sure you have SSH access or you might lose connection!${NC}"
                read -p "Are you sure? (yes/no): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    ufw default deny incoming
                    ufw --force enable
                    echo -e "${GREEN}All incoming traffic denied.${NC}"
                    log_action "Firewall Deny All" "SUCCESS"
                fi
                pause
                ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

# 6.3 SERVER
network_server_menu() {
    # Check if Nginx is installed
    if ! command -v nginx &> /dev/null; then
        show_header
        echo -e "${YELLOW}Nginx is not installed.${NC}"
        read -p "Do you want to install it now? (y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            apt update
            apt install -y nginx openssl
            if [[ $? -eq 0 ]]; then
                systemctl start nginx
                systemctl enable nginx
                echo -e "${GREEN}Nginx installed successfully.${NC}"
                log_action "Install Nginx" "SUCCESS"
            else
                echo -e "${RED}Failed to install Nginx.${NC}"
                log_action "Install Nginx" "FAILED"
                pause
                return
            fi
        else
            return
        fi
    fi
    
    while true; do
        show_header
        echo -e "${BLUE}[--------------------]${NC}"
        echo -e "${GREEN}  NETWORK > SERVER${NC}"
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. SERVER-ADD"
        echo "  2. SERVER-LISTS"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to Network Menu"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) server_add ;;
            2) server_lists ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

server_add() {
    show_header
    echo -e "${GREEN}=== ADD NGINX SERVER ===${NC}"
    echo ""
    
    read -p "Do you have a domain name? (y/n): " has_domain
    
    if [[ "$has_domain" == "y" || "$has_domain" == "Y" ]]; then
        read -p "Enter domain name (e.g., example.com): " server_name
    else
        # Get public IP
        public_ip=$(curl -s ifconfig.me)
        if [ -z "$public_ip" ]; then
            public_ip="localhost"
        fi
        server_name="$public_ip"
        echo -e "${CYAN}Using IP address: $server_name${NC}"
    fi
    
    read -p "Enter document root path (e.g., /var/www/mysite): " doc_root
    read -p "Enter HTTP port (default 80): " http_port
    http_port=${http_port:-80}
    
    read -p "Enter HTTPS port (default 443): " https_port
    https_port=${https_port:-443}
    
    # Create document root
    mkdir -p "$doc_root"
    
    # Create sample index.html
    cat > "$doc_root/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $server_name</title>
</head>
<body>
    <h1>Server is working!</h1>
    <p>This is $server_name</p>
</body>
</html>
EOF
    
    # Generate self-signed SSL certificate
    SSL_DIR="/etc/nginx/ssl/$server_name"
    mkdir -p "$SSL_DIR"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/selfsigned.key" \
        -out "$SSL_DIR/selfsigned.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$server_name" 2>/dev/null
    
    # Create Nginx config
    CONFIG_FILE="/etc/nginx/sites-available/$server_name"
    
    cat > "$CONFIG_FILE" << EOF
server {
    listen $http_port;
    listen [::]:$http_port;
    server_name $server_name;
    return 301 https://\$server_name:\$request_uri;
}

server {
    listen $https_port ssl;
    listen [::]:$https_port ssl;
    server_name $server_name;

    ssl_certificate $SSL_DIR/selfsigned.crt;
    ssl_certificate_key $SSL_DIR/selfsigned.key;

    root $doc_root;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    
    # Enable site
    ln -sf "$CONFIG_FILE" "/etc/nginx/sites-enabled/$server_name"
    
    # Test and reload Nginx
    nginx -t
    if [[ $? -eq 0 ]]; then
        systemctl reload nginx
        echo ""
        echo -e "${GREEN}Server created successfully!${NC}"
        echo -e "${CYAN}Server details:${NC}"
        echo "  Server name: $server_name"
        echo "  Document root: $doc_root"
        echo "  HTTP port: $http_port"
        echo "  HTTPS port: $https_port"
        echo "  SSL certificate: $SSL_DIR/selfsigned.crt"
        echo ""
        echo -e "${YELLOW}Access your server at:${NC}"
        echo "  http://$server_name:$http_port"
        echo "  https://$server_name:$https_port"
        log_action "Server Add" "SUCCESS - $server_name"
    else
        echo -e "${RED}Nginx configuration test failed!${NC}"
        rm -f "/etc/nginx/sites-enabled/$server_name"
        log_action "Server Add" "FAILED - $server_name"
    fi
    
    pause
}

server_lists() {
    while true; do
        show_header
        echo -e "${GREEN}=== NGINX SERVER LIST ===${NC}"
        echo ""
        
        # Get list of enabled sites
        sites=($(ls /etc/nginx/sites-enabled/ 2>/dev/null | grep -v default))
        
        if [ ${#sites[@]} -eq 0 ]; then
            echo -e "${YELLOW}No custom servers found.${NC}"
            pause
            return
        fi
        
        for i in "${!sites[@]}"; do
            echo "  $((i+1)). ${sites[$i]}"
        done
        
        echo ""
        read -p "Select server number (or 'b' to go back): " choice
        
        if [[ "$choice" == "b" || "$choice" == "B" ]]; then
            return
        fi
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#sites[@]}" ]; then
            echo -e "${RED}Invalid selection${NC}"
            pause
            continue
        fi
        
        selected_server="${sites[$((choice-1))]}"
        server_edit_menu "$selected_server"
    done
}

server_edit_menu() {
    local server_name="$1"
    
    while true; do
        show_header
        echo -e "${GREEN}=== SERVER: $server_name ===${NC}"
        echo ""
        echo -e "${BLUE}[--------------------]${NC}"
        echo "  1. VIEW CONFIG"
        echo "  2. REMOVE SERVER"
        echo -e "${BLUE}[-------------------->]${NC}"
        echo "  B. Back to Server List"
        echo -e "${BLUE}[--------------------]${NC}"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                show_header
                echo -e "${GREEN}Configuration for: $server_name${NC}"
                echo ""
                cat "/etc/nginx/sites-available/$server_name"
                pause
                ;;
            2)
                server_remove "$server_name"
                return
                ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option${NC}"; pause ;;
        esac
    done
}

server_remove() {
    local server_name="$1"
    
    show_header
    echo -e "${RED}WARNING: This will delete the server configuration!${NC}"
    echo -e "Server to delete: ${YELLOW}$server_name${NC}"
    echo ""
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Operation cancelled."
        pause
        return
    fi
    
    # Remove symlink and config
    rm -f "/etc/nginx/sites-enabled/$server_name"
    rm -f "/etc/nginx/sites-available/$server_name"
    
    # Reload Nginx
    nginx -t && systemctl reload nginx
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Server '$server_name' removed successfully.${NC}"
        log_action "Server Remove" "SUCCESS - $server_name"
    else
        echo -e "${RED}Failed to remove server.${NC}"
        log_action "Server Remove" "FAILED - $server_name"
    fi
    
    pause
}

#=============================================================================
# EXIT
#=============================================================================

exit_script() {
    show_header
    echo -e "${GREEN}Thank you for using Protocol Menu!${NC}"
    log_action "Exit Script" "SUCCESS"
    exit 0
}

#=============================================================================
# MAIN EXECUTION
#=============================================================================

# Check root privileges
check_root

# Initialize logging
init_log

# Log script start
log_action "Script Start" "SUCCESS"

# Start main menu
main_menu
