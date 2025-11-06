#!/bin/bash

# UFW Manager - Simple Bash TUI
# Author: Assistant
# Version: 1.0

# Colors for UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
TEMP_FILE="/tmp/ufw_manager.tmp"
LOG_FILE="/var/log/ufw_manager.log"

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

# Logging function
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Display header
show_header() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════╗"
    echo "║         UFW MANAGER v1.0            ║"
    echo "║    Simple Firewall Management       ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
}

# Get UFW status
get_ufw_status() {
    ufw status | grep -q "Status: active"
    if [[ $? -eq 0 ]]; then
        echo "active"
    else
        echo "inactive"
    fi
}

# Show current status
show_status() {
    show_header
    echo -e "${YELLOW}Current UFW Status:${NC}"
    ufw status numbered | head -10
    echo
}

# Show numbered rules for selection
show_rules() {
    show_header
    echo -e "${YELLOW}Current UFW Rules:${NC}"
    ufw status numbered
    echo
}

# Add rule function
add_rule() {
    show_header
    echo -e "${GREEN}Add New Rule${NC}"
    echo
    
    # Direction
    echo -e "1) Inbound"
    echo -e "2) Outbound"
    echo -e "3) Forward"
    read -p "Select direction [1-3]: " dir_choice
    
    case $dir_choice in
        1) direction="in" ;;
        2) direction="out" ;;
        3) direction="forward" ;;
        *) direction="in" ;;
    esac
    
    # Action
    echo
    echo -e "1) Allow"
    echo -e "2) Deny"  
    echo -e "3) Reject"
    echo -e "4) Limit"
    read -p "Select action [1-4]: " action_choice
    
    case $action_choice in
        1) action="allow" ;;
        2) action="deny" ;;
        3) action="reject" ;;
        4) action="limit" ;;
        *) action="allow" ;;
    esac
    
    # Port
    echo
    read -p "Port (leave empty for any): " port
    
    # Protocol
    echo
    echo -e "1) TCP"
    echo -e "2) UDP" 
    echo -e "3) Both"
    read -p "Select protocol [1-3]: " proto_choice
    
    case $proto_choice in
        1) protocol="tcp" ;;
        2) protocol="udp" ;;
        3) protocol="any" ;;
        *) protocol="any" ;;
    esac
    
    # Source/Destination
    echo
    read -p "Source IP/CIDR (leave empty for any): " source
    read -p "Destination IP/CIDR (leave empty for any): " dest
    
    # Build command
    cmd="ufw $action $direction"
    
    if [[ -n "$port" ]]; then
        if [[ "$protocol" != "any" ]]; then
            cmd="$cmd $port/$protocol"
        else
            cmd="$cmd $port"
        fi
    fi
    
    if [[ -n "$source" ]]; then
        cmd="$cmd from $source"
    fi
    
    if [[ -n "$dest" ]]; then
        cmd="$cmd to $dest"
    fi
    
    # Show and confirm
    echo
    echo -e "${YELLOW}Command to execute:${NC}"
    echo -e "${CYAN}$cmd${NC}"
    echo
    read -p "Execute this command? [y/N]: " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Executing: $cmd${NC}"
        eval "$cmd"
        log_action "Added rule: $cmd"
        read -p "Press Enter to continue..."
    else
        echo -e "${YELLOW}Cancelled${NC}"
        sleep 1
    fi
}

# Delete rule function
delete_rule() {
    while true; do
        show_rules
        echo -e "${RED}Delete Rule${NC}"
        echo
        read -p "Enter rule number to delete (or 'q' to quit): " rule_num
        
        if [[ "$rule_num" == "q" ]]; then
            break
        fi
        
        if [[ "$rule_num" =~ ^[0-9]+$ ]]; then
            echo
            echo -e "${YELLOW}Command: ufw --force delete $rule_num${NC}"
            read -p "Confirm deletion? [y/N]: " confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                ufw --force delete "$rule_num"
                log_action "Deleted rule: $rule_num"
                echo -e "${GREEN}Rule $rule_num deleted${NC}"
                sleep 2
            else
                echo -e "${YELLOW}Deletion cancelled${NC}"
                sleep 1
            fi
        else
            echo -e "${RED}Invalid rule number${NC}"
            sleep 2
        fi
    done
}

# Search rules function
search_rules() {
    show_header
    echo -e "${GREEN}Search Rules${NC}"
    echo
    read -p "Enter search term: " search_term
    
    if [[ -n "$search_term" ]]; then
        echo
        echo -e "${YELLOW}Matching rules:${NC}"
        ufw status numbered | grep -i "$search_term" || echo "No matches found"
    else
        ufw status numbered
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Enable/disable UFW
toggle_ufw() {
    show_header
    current_status=$(get_ufw_status)
    
    if [[ "$current_status" == "active" ]]; then
        echo -e "${RED}Disable UFW${NC}"
        echo
        read -p "Are you sure you want to disable UFW? [y/N]: " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            ufw --force disable
            log_action "UFW disabled"
            echo -e "${GREEN}UFW disabled${NC}"
        else
            echo -e "${YELLOW}Cancelled${NC}"
        fi
    else
        echo -e "${GREEN}Enable UFW${NC}"
        echo
        read -p "Are you sure you want to enable UFW? [y/N]: " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            ufw --force enable
            log_action "UFW enabled"
            echo -e "${GREEN}UFW enabled${NC}"
        else
            echo -e "${YELLOW}Cancelled${NC}"
        fi
    fi
    
    sleep 2
}

# Reset UFW
reset_ufw() {
    show_header
    echo -e "${RED}RESET UFW${NC}"
    echo
    echo -e "${YELLOW}WARNING: This will reset ALL UFW rules to defaults!${NC}"
    echo
    read -p "Are you absolutely sure? [y/N]: " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        read -p "Type 'RESET' to confirm: " confirm_reset
        
        if [[ "$confirm_reset" == "RESET" ]]; then
            ufw --force reset
            log_action "UFW reset to defaults"
            echo -e "${GREEN}UFW has been reset to defaults${NC}"
        else
            echo -e "${YELLOW}Reset cancelled${NC}"
        fi
    else
        echo -e "${YELLOW}Reset cancelled${NC}"
    fi
    
    sleep 2
}

# Show application logs
show_logs() {
    show_header
    echo -e "${YELLOW}Application Logs${NC}"
    echo
    
    if [[ -f "$LOG_FILE" ]]; then
        tail -20 "$LOG_FILE"
    else
        echo "No log file found"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Main menu
main_menu() {
    while true; do
        show_header
        current_status=$(get_ufw_status)
        
        if [[ "$current_status" == "active" ]]; then
            status_display="${GREEN}ACTIVE${NC}"
        else
            status_display="${RED}INACTIVE${NC}"
        fi
        
        echo -e "UFW Status: $status_display"
        echo
        echo -e "${CYAN}Main Menu:${NC}"
        echo -e "1) ${GREEN}Show Status${NC}"
        echo -e "2) ${BLUE}Add Rule${NC}"
        echo -e "3) ${YELLOW}Delete Rule${NC}"
        echo -e "4) ${CYAN}Search Rules${NC}"
        echo -e "5) ${GREEN}Enable/Disable UFW${NC}"
        echo -e "6) ${RED}Reset UFW${NC}"
        echo -e "7) ${BLUE}View Logs${NC}"
        echo -e "8) ${RED}Exit${NC}"
        echo
        
        read -p "Select option [1-8]: " choice
        
        case $choice in
            1)
                show_status
                read -p "Press Enter to continue..."
                ;;
            2)
                add_rule
                ;;
            3)
                delete_rule
                ;;
            4)
                search_rules
                ;;
            5)
                toggle_ufw
                ;;
            6)
                reset_ufw
                ;;
            7)
                show_logs
                ;;
            8)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Initialization
init() {
    check_root
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    # Log script start
    log_action "UFW Manager started"
    
    # Check if UFW is installed
    if ! command -v ufw &> /dev/null; then
        echo -e "${RED}Error: UFW is not installed${NC}"
        echo "Install with: apt install ufw"
        exit 1
    fi
}

# Main execution
init
main_menu
