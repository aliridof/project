#!/bin/bash

echo "=========================================="
echo "           NETWORK INFORMATION"
echo "=========================================="

# IP Address Information
public_ip=$(curl -s --connect-timeout 5 https://api.ipify.org || echo "Tidak terdeteksi")
private_ip=$(hostname -I | awk '{print $1}')
domain=$(hostname -d || echo "Tidak terdeteksi")

echo "IP ADDRESS:"
echo "| PUBLIC:  $public_ip"
echo "| PRIVATE: $private_ip"
echo "DOMAIN:    $domain"

echo ""
echo "=========================================="
echo "            PORT SCANNING"
echo "=========================================="

# Simple port listing
if command -v ss &> /dev/null; then
    echo "Port yang terbuka:"
    ss -tuln | grep LISTEN
else
    netstat -tuln 2>/dev/null | grep LISTEN
fi

echo ""
echo "=========================================="
echo "          FIREWALL STATUS"
echo "=========================================="

# Check and install UFW if not available
if ! command -v ufw &> /dev/null; then
    echo "UFW tidak terdeteksi. Menginstal UFW..."
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install ufw -y
        sudo ufw enable
    elif command -v yum &> /dev/null; then
        sudo yum install ufw -y
        sudo ufw enable
    fi
fi

# Show UFW status
if command -v ufw &> /dev/null; then
    echo "UFW Status:"
    sudo ufw status
else
    echo "UFW gagal diinstal atau tidak tersedia"
fi
