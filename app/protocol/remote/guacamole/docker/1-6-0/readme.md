# Persiapan Instalasi Guacamole via Docker di GCP E2 Micro

## ⚠️ PERHATIAN PENTING - KETERBATASAN SPESIFIKASI

Dengan **RAM 1GB**, server Anda akan sangat terbatas. Guacamole + Database + Docker membutuhkan minimal 1.5-2GB RAM. Anda **HARUS** membuat swap memory.

---

## 📋 CHECKLIST PERSIAPAN

### **1. KONEKSI & AKSES AWAL**

```bash
# SSH ke server
ssh root@35.208.16.99
# atau jika menggunakan user ubuntu
ssh ubuntu@35.208.16.99
```

---

### **2. UPDATE SISTEM**

```bash
# Update package list
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y curl wget git nano ufw net-tools htop
```

sudo apt install mc -y 
sudo apt install micro -y 
sudo apt install ufw -y 

---

### **3. BUAT SWAP MEMORY (WAJIB!)**

```bash
# Cek swap saat ini
free -h

# Buat swap 2GB (karena RAM hanya 1GB)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Permanent swap
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Optimasi swap
sudo sysctl vm.swappiness=10
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# Verifikasi
free -h
```

---

### **4. INSTALL DOCKER & DOCKER COMPOSE**

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Start & enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user ke docker group (opsional)
sudo usermod -aG docker $USER

# Install Docker Compose V2 (sudah include di Docker modern)
# Verifikasi
docker --version
docker compose version
```

---

### **5. KONFIGURASI FIREWALL GCP**

**Via GCP Console:**

1. Buka **VPC Network** → **Firewall**
2. **Create Firewall Rule**:

```
Name: allow-guacamole
Targets: All instances in the network
Source IP ranges: 0.0.0.0/0 (atau IP spesifik untuk keamanan)
Protocols and ports: 
  - tcp:80
  - tcp:443
  - tcp:8080 (port Guacamole default)
```

**Via gcloud CLI (alternatif):**

```bash
gcloud compute firewall-rules create allow-guacamole \
    --allow tcp:80,tcp:443,tcp:8080 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow Guacamole access"
```

---

### **6. KONFIGURASI UFW (Ubuntu Firewall)**

```bash
# Enable UFW
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp

# Enable firewall
sudo ufw --force enable

# Cek status
sudo ufw status verbose
```

---

### **7. PERSIAPAN DIREKTORI**

```bash
# Buat direktori untuk Guacamole
mkdir -p ~/guacamole
cd ~/guacamole

# Buat subdirektori
mkdir -p {mysql,postgres,init,drive,record}
```

---

### **8. PERSIAPAN DATABASE INITIALIZATION**

```bash
# Download init script untuk MySQL/MariaDB
cd ~/guacamole/init

# Ambil versi terbaru (contoh 1.5.4)
MYSQL 
wget https://raw.githubusercontent.com/aliridof/project/main/app/protocol/remote/guacamole/docker/1-6-0/mysql/schema/001-create-schema.sql -O 001-create-schema.sql
wget https://raw.githubusercontent.com/aliridof/project/main/app/protocol/remote/guacamole/docker/1-6-0/mysql/schema/002-create-admin-user.sql -O 002-create-admin-user.sql

POSTGRESQL
wget https://raw.githubusercontent.com/aliridof/project/main/app/protocol/remote/guacamole/docker/1-6-0/postgresql/schema/001-create-schema.sql -O 001-create-schema.sql
wget https://raw.githubusercontent.com/aliridof/project/main/app/protocol/remote/guacamole/docker/1-6-0/postgresql/schema/002-create-admin-user.sql -O 002-create-admin-user.sql

# Atau gunakan Docker untuk generate
docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --mysql > initdb.sql
```

---

### **9. BUAT DOCKER COMPOSE FILE**

```bash
cd ~/guacamole
nano docker-compose.yml
```

**Paste konfigurasi ini (OPTIMIZED untuk 1GB RAM):**

```yaml
version: '3.8'

services:
  guacd:
    image: guacamole/guacd
    container_name: guacd
    restart: unless-stopped
    networks:
      - guacamole-net
    deploy:
      resources:
        limits:
          memory: 256M

  mysql:
    image: mysql:8.0
    container_name: guacamole-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: guacamole_db
      MYSQL_USER: guacamole_user
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - ./mysql:/var/lib/mysql
      - ./init:/docker-entrypoint-initdb.d:ro
    networks:
      - guacamole-net
    deploy:
      resources:
        limits:
          memory: 384M
    command: --default-authentication-plugin=mysql_native_password --innodb-buffer-pool-size=128M

  guacamole:
    image: guacamole/guacamole
    container_name: guacamole
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      GUACD_HOSTNAME: guacd
      MYSQL_HOSTNAME: mysql
      MYSQL_DATABASE: guacamole_db
      MYSQL_USER: guacamole_user
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    depends_on:
      - guacd
      - mysql
    networks:
      - guacamole-net
    deploy:
      resources:
        limits:
          memory: 384M

networks:
  guacamole-net:
    driver: bridge
```

---

### **10. BUAT FILE ENVIRONMENT**

```bash
nano .env
```

**Paste:**

```env
MYSQL_ROOT_PASSWORD=[ISI_PASSWORD]
MYSQL_PASSWORD=[ISI_PASSWORD]
```

**Amankan file:**

```bash
chmod 600 .env
```

---

### **11. MONITORING RESOURCE (WAJIB!)**

```bash
# Install monitoring tools
sudo apt install -y htop iotop

# Jalankan untuk monitor
htop
```

---

## 🚀 TESTING SEBELUM INSTALL

```bash
# Cek Docker berjalan
sudo systemctl status docker

# Cek disk space
df -h

# Cek memory
free -h

# Test Docker
docker run hello-world

# Cek network
curl -I https://hub.docker.com
```

---

## 📊 EXPECTED RESOURCE USAGE

| Service | Memory | CPU |
|---------|--------|-----|
| guacd | ~100-150MB | 5-10% |
| MySQL | ~200-300MB | 10-20% |
| Guacamole | ~250-350MB | 15-25% |
| **Total** | **~600-800MB** | **30-55%** |

Dengan swap, sistem akan tetap berjalan tapi **bisa lambat**.

---

## ⚡ OPTIMASI TAMBAHAN (OPSIONAL)

```bash
# Disable unnecessary services
sudo systemctl disable snapd
sudo systemctl stop snapd

# Clean up
sudo apt autoremove -y
sudo apt clean

# Limit journal size
sudo journalctl --vacuum-time=3d
```

---

## 🔐 SECURITY CHECKLIST

- [ ] Swap sudah aktif
- [ ] Firewall GCP configured
- [ ] UFW enabled
- [ ] SSH key-based auth (recommended)
- [ ] Password complexity di .env file
- [ ] File .env permission 600
- [ ] Regular backup plan

---

## ✅ READY TO INSTALL!

Setelah semua checklist di atas selesai, jalankan:

```bash
cd ~/guacamole
docker compose up -d
```

Akses Guacamole di: **http://35.208.16.99:8080/guacamole**

**Default login:**
- Username: `guacadmin`
- Password: `guacadmin`

---

**Apakah Anda ingin saya buatkan script instalasi otomatis atau ada yang perlu dijelaskan lebih detail?**



# 🔒 TUTORIAL NGINX REVERSE PROXY + SSL UNTUK GUACAMOLE

## 📋 **PREREQUISITES**
- Guacamole sudah running di port 8080
- Ubuntu server dengan akses sudo
- IP: 35.208.16.99 (sesuaikan dengan IP Anda)

---

## **PART 1: INSTALL & SETUP NGINX**

### **1. Install Nginx**
```bash
# Update & install Nginx
sudo apt update
sudo apt install -y nginx

# Verify installation
nginx -v

# Start & enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Check status
sudo systemctl status nginx
```

### **2. Backup Default Config**
```bash
# Backup original config
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
```

---

## **PART 2: SELF-SIGNED SSL CERTIFICATE**

### **1. Create SSL Directory**
```bash
# Create directory for SSL certificates
sudo mkdir -p /etc/nginx/ssl
cd /etc/nginx/ssl
```

### **2. Generate Self-Signed Certificate**
```bash
# Generate private key & certificate (valid 365 days)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/guacamole-selfsigned.key \
    -out /etc/nginx/ssl/guacamole-selfsigned.crt
```

**Isi prompt yang muncul:**
```
Country Name (2 letter code): ID
State or Province Name: Jakarta
Locality Name: Jakarta
Organization Name: MyCompany
Organizational Unit Name: IT
Common Name: 35.208.16.99    # <-- Ganti dengan IP server Anda
Email Address: admin@example.com
```

### **3. Generate Diffie-Hellman Group (Opsional tapi recommended)**
```bash
# Ini akan memakan waktu 1-2 menit
sudo openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
```

### **4. Verify SSL Files**
```bash
# Check files created
ls -la /etc/nginx/ssl/

# Should show:
# guacamole-selfsigned.crt
# guacamole-selfsigned.key
# dhparam.pem
```

---

## **PART 3: KONFIGURASI NGINX UNTUK GUACAMOLE**

### **1. Create Guacamole Site Config**
```bash
# Create new config file
sudo nano /etc/nginx/sites-available/guacamole
```

### **2. Paste Configuration (PILIH SALAH SATU)**

#### **OPSI A: HTTPS Only (Recommended)**
```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name 35.208.16.99;  # Ganti dengan IP Anda
    
    return 301 https://$server_name$request_uri;
}

# HTTPS Server Block
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name 35.208.16.99;  # Ganti dengan IP Anda

    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/guacamole-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/guacamole-selfsigned.key;
    ssl_dhparam /etc/nginx/ssl/dhparam.pem;

    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Logging
    access_log /var/log/nginx/guacamole-access.log;
    error_log /var/log/nginx/guacamole-error.log;

    # Max body size for file uploads
    client_max_body_size 1024M;

    # Proxy Settings for Guacamole
    location / {
        proxy_pass http://localhost:8080/guacamole/;
        proxy_buffering off;
        proxy_http_version 1.1;
        
        # Headers required for Guacamole
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # WebSocket support (required for Guacamole)
    location /guacamole/websocket-tunnel {
        proxy_pass http://localhost:8080/guacamole/websocket-tunnel;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        
        # WebSocket timeout (set higher for long sessions)
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
```

#### **OPSI B: HTTP & HTTPS (Testing/Development)**
```nginx
# HTTP Server Block
server {
    listen 80;
    listen [::]:80;
    server_name 35.208.16.99;  # Ganti dengan IP Anda

    location / {
        proxy_pass http://localhost:8080/guacamole/;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;
    }
}

# HTTPS Server Block
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name 35.208.16.99;  # Ganti dengan IP Anda

    ssl_certificate /etc/nginx/ssl/guacamole-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/guacamole-selfsigned.key;

    location / {
        proxy_pass http://localhost:8080/guacamole/;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;
    }
}
```

### **3. Enable Site Configuration**
```bash
# Disable default site
sudo rm /etc/nginx/sites-enabled/default

# Enable guacamole site
sudo ln -s /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# If output shows "syntax is ok", reload Nginx
sudo systemctl reload nginx
```

---

## **PART 4: FIREWALL CONFIGURATION**

### **1. Update UFW Rules**
```bash
# Add HTTPS rule
sudo ufw allow 443/tcp
sudo ufw allow 'Nginx Full'

# Optional: Remove direct access to port 8080 (setelah testing)
# sudo ufw delete allow 8080/tcp

# Check status
sudo ufw status numbered
```

### **2. Update GCP Firewall (Via Console atau gcloud)**
```bash
# Via gcloud CLI
gcloud compute firewall-rules create allow-https \
    --allow tcp:443 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow HTTPS access"

# Or update existing rule
gcloud compute firewall-rules update allow-guacamole \
    --allow tcp:80,tcp:443 \
    --source-ranges 0.0.0.0/0
```

---

## **PART 5: TESTING & TROUBLESHOOTING**

### **1. Test Nginx Status**
```bash
# Check Nginx status
sudo systemctl status nginx

# Check for errors
sudo nginx -t

# View error logs
sudo tail -f /var/log/nginx/error.log

# View access logs
sudo tail -f /var/log/nginx/guacamole-access.log
```

### **2. Test Connections**
```bash
# Test local Guacamole
curl -I http://localhost:8080/guacamole/

# Test Nginx proxy
curl -kI https://localhost/

# Test from external
curl -kI https://35.208.16.99/
```

### **3. Browser Access**
```
# Access via HTTPS (akan ada warning karena self-signed)
https://35.208.16.99

# Browser akan warning "Not Secure" - klik:
- Advanced
- Proceed to 35.208.16.99 (unsafe)
```

---

## **PART 6: OPTIMASI & TUNING**

### **1. Nginx Performance Tuning**
```bash
# Edit main config
sudo nano /etc/nginx/nginx.conf
```

**Update worker settings:**
```nginx
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # Buffer settings
    client_body_buffer_size 128k;
    client_max_body_size 1024M;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 8k;
    output_buffers 32 32k;
    postpone_output 1460;

    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml application/atom+xml image/svg+xml text/x-js text/x-cross-domain-policy application/x-font-ttf application/x-font-opentype application/vnd.ms-fontobject image/x-icon;
    gzip_disable "msie6";
}
```

### **2. Connection Timeout untuk RDP Sessions**
```bash
# Edit guacamole site config
sudo nano /etc/nginx/sites-available/guacamole
```

**Add/update di location block:**
```nginx
    # Longer timeouts for RDP sessions
    proxy_connect_timeout 7d;
    proxy_send_timeout 7d;
    proxy_read_timeout 7d;
    send_timeout 7d;
```

---

## **PART 7: OPTIONAL - SETUP DENGAN DOMAIN**

### **A. Jika Punya Domain (example.com)**

#### **1. Update DNS Record**
```
Type: A
Name: guac (atau subdomain lain)
Value: 35.208.16.99
TTL: 300
```

#### **2. Update Nginx Config**
```bash
sudo nano /etc/nginx/sites-available/guacamole
```

**Ganti `server_name`:**
```nginx
server_name guac.example.com;  # Ganti 35.208.16.99
```

#### **3. Install Let's Encrypt SSL (Free)**
```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Generate certificate
sudo certbot --nginx -d guac.example.com

# Auto-renewal test
sudo certbot renew --dry-run
```

### **B. Menggunakan Dynamic DNS (Gratis)**

**Services gratis:**
- DuckDNS.org
- No-IP.com
- Dynu.com

**Contoh dengan DuckDNS:**
```bash
# 1. Register di duckdns.org
# 2. Buat subdomain: myguac.duckdns.org
# 3. Update IP

# Auto update script
cat > ~/duckdns-update.sh << 'EOF'
#!/bin/bash
echo url="https://www.duckdns.org/update?domains=myguac&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns.log -K -
EOF

chmod +x ~/duckdns-update.sh

# Add to cron
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/duckdns-update.sh") | crontab -
```

---

## **PART 8: MONITORING & LOGS**

### **1. Setup Log Rotation**
```bash
# Create logrotate config
sudo nano /etc/logrotate.d/nginx-guacamole
```

**Paste:**
```
/var/log/nginx/guacamole-*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 640 www-data adm
    sharedscripts
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 `cat /var/run/nginx.pid`
        fi
    endscript
}
```

### **2. Real-time Monitoring**
```bash
# Watch access logs
sudo tail -f /var/log/nginx/guacamole-access.log

# Monitor Nginx connections
watch -n 1 'sudo netstat -anp | grep :443 | wc -l'

# Check Nginx status
curl http://localhost/nginx_status
```

### **3. Enable Nginx Status Page (Optional)**
```nginx
# Add to nginx config
server {
    listen 127.0.0.1:80;
    server_name localhost;
    
    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}
```

---

## **PART 9: SECURITY HARDENING**

### **1. Rate Limiting**
```nginx
# Add to http block in /etc/nginx/nginx.conf
http {
    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_conn_zone $binary_remote_addr zone=addr:10m;
}

# Add to location / in sites-available/guacamole
location / {
    limit_req zone=general burst=20 nodelay;
    limit_conn addr 10;
    # ... rest of config
}

location /guacamole/api/tokens {
    limit_req zone=login burst=5 nodelay;
    # ... rest of config
}
```

### **2. IP Whitelisting (Optional)**
```nginx
# Allow specific IPs only
location / {
    allow 192.168.1.0/24;  # Local network
    allow 203.0.113.0/24;  # Office IP range
    allow 198.51.100.5;    # Specific IP
    deny all;
    
    # ... proxy settings
}
```

### **3. Basic Authentication (Extra Layer)**
```bash
# Create password file
sudo apt install -y apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Add to location block
location / {
    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
    # ... proxy settings
}
```

---

## **PART 10: QUICK TROUBLESHOOTING**

### **Common Issues & Solutions:**

#### **1. 502 Bad Gateway**
```bash
# Check if Guacamole is running
docker ps
docker compose -f ~/guacamole/docker-compose.yml ps

# Restart Guacamole
cd ~/guacamole
docker compose restart

# Check logs
docker compose logs guacamole
```

#### **2. SSL Certificate Warning**
```bash
# Normal untuk self-signed certificate
# Solusi: Gunakan domain + Let's Encrypt
```

#### **3. Connection Timeout**
```bash
# Increase timeout in Nginx config
proxy_connect_timeout 300s;
proxy_send_timeout 300s;
proxy_read_timeout 300s;
```

#### **4. WebSocket Connection Failed**
```bash
# Ensure WebSocket headers are set
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

---

## ✅ **VERIFICATION CHECKLIST**

```bash
# Run this verification script
cat > ~/verify-nginx-ssl.sh << 'EOF'
#!/bin/bash
echo "=== NGINX SSL VERIFICATION ==="
echo ""
echo "1. Nginx Status:"
systemctl is-active nginx
echo ""
echo "2. SSL Certificate:"
sudo openssl x509 -in /etc/nginx/ssl/guacamole-selfsigned.crt -text -noout | grep Subject:
echo ""
echo "3. Listening Ports:"
sudo netstat -tlnp | grep -E ':(80|443|8080)'
echo ""
echo "4. Test HTTPS:"
curl -kI https://localhost/ 2>/dev/null | head -n 1
echo ""
echo "5. Guacamole Container:"
docker ps | grep guacamole
echo ""
echo "=== Access URLs ==="
echo "HTTPS: https://$(curl -s ifconfig.me)/"
echo "HTTP:  http://$(curl -s ifconfig.me)/"
echo ""
echo "Default login: guacadmin / guacadmin"
EOF

chmod +x ~/verify-nginx-ssl.sh
~/verify-nginx-ssl.sh
```

---

## 🎯 **FINAL NOTES**

### **Access Methods After Setup:**
```
✅ HTTPS (Recommended): https://35.208.16.99/
✅ HTTP (Redirect):     http://35.208.16.99/
❌ Direct (Block ini):  http://35.208.16.99:8080/guacamole
```

### **Browser Warning untuk Self-Signed:**
1. Chrome: Advanced → Proceed to site
2. Firefox: Advanced → Accept Risk
3. Edge: Advanced → Continue to site

### **Security Reminder:**
- ✅ Change default password IMMEDIATELY
- ✅ Create new admin user
- ✅ Setup fail2ban
- ✅ Regular backup
- ✅ Monitor logs

---

**Need help? Check logs:**
```bash
# Nginx errors
sudo tail -f /var/log/nginx/error.log

# Guacamole logs
docker compose -f ~/guacamole/docker-compose.yml logs -f
```

