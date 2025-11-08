# Panduan Lengkap Konfigurasi NGINX - Semua Skenario

## DAFTAR ISI
1. [Skenario 1: Single Domain - Single Service](#skenario-1-single-domain---single-service)
2. [Skenario 2: Single Domain - Multiple Services (Path-based)](#skenario-2-single-domain---multiple-services-path-based)
3. [Skenario 3: Multiple Subdomains](#skenario-3-multiple-subdomains)
4. [Skenario 4: Load Balancing](#skenario-4-load-balancing)
5. [Skenario 5: Static Files + API Backend](#skenario-5-static-files--api-backend)
6. [Skenario 6: SSL/HTTPS Configuration](#skenario-6-sslhttps-configuration)
7. [Skenario 7: WebSocket Support](#skenario-7-websocket-support)
8. [Skenario 8: Rate Limiting & Security](#skenario-8-rate-limiting--security)
9. [Skenario 9: Caching Strategy](#skenario-9-caching-strategy)
10. [Skenario 10: Docker & Container Integration](#skenario-10-docker--container-integration)
11. [Skenario 11: Microservices Architecture](#skenario-11-microservices-architecture)
12. [Skenario 12: Blue-Green Deployment](#skenario-12-blue-green-deployment)
13. [Performance Optimization](#performance-optimization)
14. [Monitoring & Logging](#monitoring--logging)
15. [Troubleshooting](#troubleshooting)
16. [Best Practices & Tips](#best-practices--tips)

---

## SKENARIO 1: Single Domain - Single Service

### Use Case
Satu domain untuk satu aplikasi/service saja.

### Contoh
```
example.com → Web Application
```

### Cloudflare DNS
| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | example.com | YOUR_IP | ✓ |

### NGINX Config
**File:** `/etc/nginx/sites-available/example.com`

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    # Root directory untuk static files
    root /var/www/example.com;
    index index.html index.htm index.php;

    # Log files
    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Main location
    location / {
        try_files $uri $uri/ =404;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Deny access to sensitive files
    location ~ \.(sql|log|bak|backup|env)$ {
        deny all;
    }
}
```

### Setup Commands
```bash
# Buat directory web
sudo mkdir -p /var/www/example.com

# Set permissions
sudo chown -R www-data:www-data /var/www/example.com
sudo chmod -R 755 /var/www/example.com

# Buat test file
echo "<h1>Welcome to Example.com</h1>" | sudo tee /var/www/example.com/index.html

# Enable site
sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/

# Test & reload
sudo nginx -t
sudo systemctl reload nginx
```

---

## SKENARIO 2: Single Domain - Multiple Services (Path-based)

### Use Case
Satu domain untuk beberapa service dengan path berbeda.

### Contoh
```
example.com           → Main App
example.com/admin     → Admin Panel
example.com/api       → API Backend
example.com/docs      → Documentation
```

### Cloudflare DNS
| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | example.com | YOUR_IP | ✓ |

### NGINX Config
**File:** `/etc/nginx/sites-available/example.com`

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    # Log files
    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;

    # Client body size limit
    client_max_body_size 100M;

    # ==================================================
    # /api - API Backend (Port 3000)
    # ==================================================
    location /api/ {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # ==================================================
    # /admin - Admin Panel (Port 4000)
    # ==================================================
    location /admin/ {
        proxy_pass http://localhost:4000/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # ==================================================
    # /docs - Documentation (Static files)
    # ==================================================
    location /docs {
        alias /var/www/example.com/docs;
        index index.html;
        try_files $uri $uri/ /docs/index.html;
        
        # Cache control for docs
        expires 1h;
        add_header Cache-Control "public, must-revalidate";
    }

    # ==================================================
    # / - Main Application (Port 8080)
    # ==================================================
    location / {
        proxy_pass http://localhost:8080/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### PENTING: Urutan Location Block
```nginx
# ✅ BENAR - Spesifik ke general
location /api/admin {      # Paling spesifik
location /api/ {           # Spesifik
location / {               # General (catch-all)

# ❌ SALAH - General di atas akan menimpa semua
location / {               # Catch-all
location /api/ {           # Tidak akan pernah tercapai!
```

---

## SKENARIO 3: Multiple Subdomains

### Use Case
Beberapa subdomain untuk service berbeda.

### Contoh
```
example.com           → Landing Page
app.example.com       → Main Application
admin.example.com     → Admin Panel
api.example.com       → API Backend
docs.example.com      → Documentation
```

### Cloudflare DNS
| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | example.com | YOUR_IP | ✓ |
| A | *.example.com | YOUR_IP | ✓ |

### NGINX Config

#### Metode 1: File Terpisah per Subdomain (Recommended)

**File:** `/etc/nginx/sites-available/example.com`
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    root /var/www/example.com;
    index index.html;

    access_log /var/log/nginx/main.access.log;
    error_log /var/log/nginx/main.error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

**File:** `/etc/nginx/sites-available/app.example.com`
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name app.example.com;

    access_log /var/log/nginx/app.access.log;
    error_log /var/log/nginx/app.error.log;

    location / {
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

**File:** `/etc/nginx/sites-available/admin.example.com`
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name admin.example.com;

    access_log /var/log/nginx/admin.access.log;
    error_log /var/log/nginx/admin.error.log;

    # Basic Auth untuk keamanan
    auth_basic "Admin Area";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass http://localhost:4000;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

**File:** `/etc/nginx/sites-available/api.example.com`
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name api.example.com;

    access_log /var/log/nginx/api.access.log combined;
    error_log /var/log/nginx/api.error.log;

    # CORS headers
    add_header Access-Control-Allow-Origin * always;
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;

    # Handle preflight requests
    if ($request_method = 'OPTIONS') {
        return 204;
    }

    location / {
        proxy_pass http://localhost:5000;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

#### Metode 2: Satu File untuk Semua Subdomain

**File:** `/etc/nginx/sites-available/all-subdomains`
```nginx
# Landing Page
server {
    listen 80;
    server_name example.com www.example.com;
    root /var/www/example.com;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}

# App
server {
    listen 80;
    server_name app.example.com;
    
    location / {
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}

# Admin
server {
    listen 80;
    server_name admin.example.com;
    
    auth_basic "Admin Area";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    location / {
        proxy_pass http://localhost:4000;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}

# API
server {
    listen 80;
    server_name api.example.com;
    
    location / {
        proxy_pass http://localhost:5000;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

### Setup Commands
```bash
# Create htpasswd for admin
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Metode 1: Enable semua file
sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/app.example.com /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/admin.example.com /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/api.example.com /etc/nginx/sites-enabled/

# Test & reload
sudo nginx -t
sudo systemctl reload nginx
```

---

## SKENARIO 4: Load Balancing

### Use Case
Distribute traffic ke beberapa backend server.

### Contoh
```
example.com → Load balancer ke 3 backend servers
```

### NGINX Config
**File:** `/etc/nginx/sites-available/example.com`

```nginx
# ==================================================
# Upstream Configuration
# ==================================================
upstream backend_servers {
    # Load balancing method
    least_conn;  # Options: round_robin (default), least_conn, ip_hash
    
    # Backend servers
    server 192.168.1.10:8080 weight=3 max_fails=3 fail_timeout=30s;
    server 192.168.1.11:8080 weight=2 max_fails=3 fail_timeout=30s;
    server 192.168.1.12:8080 weight=1 max_fails=3 fail_timeout=30s;
    
    # Backup server
    server 192.168.1.13:8080 backup;
    
    # Health check settings
    keepalive 32;
    keepalive_timeout 60s;
}

server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    access_log /var/log/nginx/lb.access.log;
    error_log /var/log/nginx/lb.error.log;

    location / {
        proxy_pass http://backend_servers;
        proxy_http_version 1.1;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Connection management
        proxy_set_header Connection "";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Retry logic
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        proxy_next_upstream_tries 3;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

### Load Balancing Methods

```nginx
# 1. Round Robin (default) - Bergiliran
upstream backend {
    server server1:8080;
    server server2:8080;
    server server3:8080;
}

# 2. Least Connections - Ke server dengan koneksi paling sedikit
upstream backend {
    least_conn;
    server server1:8080;
    server server2:8080;
    server server3:8080;
}

# 3. IP Hash - User yang sama selalu ke server yang sama
upstream backend {
    ip_hash;
    server server1:8080;
    server server2:8080;
    server server3:8080;
}

# 4. Weighted - Distribusi berdasarkan weight
upstream backend {
    server server1:8080 weight=3;
    server server2:8080 weight=2;
    server server3:8080 weight=1;
}

# 5. Hash (Generic) - Based on custom key
upstream backend {
    hash $request_uri consistent;
    server server1:8080;
    server server2:8080;
    server server3:8080;
}
```

---

## SKENARIO 5: Static Files + API Backend

### Use Case
Frontend static files + Backend API terpisah.

### Contoh
```
example.com/           → React/Vue/Angular static files
example.com/api/       → Backend API
example.com/uploads/   → User uploaded files
```

### NGINX Config
**File:** `/etc/nginx/sites-available/example.com`

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    # Root untuk static files
    root /var/www/example.com/dist;
    index index.html;

    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;

    # Client upload size
    client_max_body_size 100M;

    # ==================================================
    # API Backend
    # ==================================================
    location /api/ {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Disable buffering untuk streaming/upload
        proxy_buffering off;
        proxy_request_buffering off;
    }

    # ==================================================
    # User Uploads
    # ==================================================
    location /uploads/ {
        alias /var/www/example.com/uploads/;
        
        # Security - prevent script execution
        location ~ \.(php|pl|py|jsp|asp|sh|cgi)$ {
            deny all;
        }
        
        # Cache control
        expires 30d;
        add_header Cache-Control "public, immutable";
        
        # CORS if needed
        add_header Access-Control-Allow-Origin *;
    }

    # ==================================================
    # Static Assets (CSS, JS, Images)
    # ==================================================
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot|webp)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
        
        # Enable gzip compression
        gzip_static on;
    }

    # ==================================================
    # Frontend SPA (React/Vue/Angular)
    # ==================================================
    location / {
        try_files $uri $uri/ /index.html;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    }

    # ==================================================
    # Deny access to hidden files
    # ==================================================
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # ==================================================
    # Deny access to sensitive files
    # ==================================================
    location ~ \.(sql|log|bak|backup|env|git)$ {
        deny all;
    }
}
```

---

## SKENARIO 6: SSL/HTTPS Configuration

### Metode 1: Let's Encrypt (Gratis, Otomatis) - RECOMMENDED

```bash
# Install Certbot
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# Dapatkan certificate untuk single domain
sudo certbot --nginx -d example.com -d www.example.com

# Dapatkan certificate untuk multiple subdomains
sudo certbot --nginx \
    -d example.com \
    -d www.example.com \
    -d app.example.com \
    -d admin.example.com \
    -d api.example.com

# Auto-renewal test
sudo certbot renew --dry-run

# View certificates
sudo certbot certificates
```

### NGINX Config Setelah SSL
**File:** `/etc/nginx/sites-available/example.com`

```nginx
# ==================================================
# HTTP - Redirect to HTTPS
# ==================================================
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    # Allow Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect all HTTP to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# ==================================================
# HTTPS
# ==================================================
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name example.com www.example.com;

    # SSL Certificate (Certbot akan otomatis menambahkan ini)
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    
    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    
    # SSL Session
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Root & Index
    root /var/www/example.com;
    index index.html;

    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Metode 2: SSL Manual (Self-signed untuk Testing)

```bash
# Generate self-signed certificate
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout /etc/nginx/ssl/example.com.key \
    -out /etc/nginx/ssl/example.com.crt \
    -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Example/CN=example.com"

# Generate DH parameters (for better security)
sudo openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
```

**NGINX Config:**
```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;
    ssl_dhparam /etc/nginx/ssl/dhparam.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # ... rest of config
}
```

---

## SKENARIO 7: WebSocket Support

### Use Case
Real-time applications (chat, live updates, gaming, notifications).

### Contoh
```
example.com/ws        → WebSocket connection
example.com/socket.io → Socket.io connection
example.com/          → Regular HTTP
```

### NGINX Config
**File:** `/etc/nginx/sites-available/example.com`

```nginx
# ==================================================
# WebSocket upgrade map
# ==================================================
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    server_name example.com;

    # ==================================================
    # WebSocket endpoint
    # ==================================================
    location /ws {
        proxy_pass http://localhost:3000;
        
        # WebSocket headers
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        
        # Standard headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts (penting untuk WebSocket long-lived connections)
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
        
        # Disable buffering
        proxy_buffering off;
        
        # Prevent connection close
        proxy_set_header Connection "";
    }

    # ==================================================
    # Socket.io support (jika pakai Socket.io)
    # ==================================================
    location /socket.io/ {
        proxy_pass http://localhost:3000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Socket.io specific
        proxy_buffering off;
        proxy_redirect off;
        
        # Timeouts
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }

    # ==================================================
    # Regular HTTP
    # ==================================================
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### WebSocket dengan SSL/HTTPS

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    location /ws {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        
        # WSS (WebSocket Secure) headers
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Timeouts
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
        
        proxy_buffering off;
    }
}
```

### Testing WebSocket

```bash
# Install wscat untuk testing
npm install -g wscat

# Test WebSocket connection
wscat -c ws://example.com/ws

# Test WebSocket Secure connection
wscat -c wss://example.com/ws
```

---

## SKENARIO 8: Rate Limiting & Security

### Use Case
Protect dari abuse, DDoS, brute force attacks.

### NGINX Config
**File:** `/etc/nginx/sites-available/example.com`

```nginx
# ==================================================
# Rate Limiting Zones (tambahkan di http block atau di sini)
# ==================================================
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=100r/s;
limit_req_zone $binary_remote_addr zone=search:10m rate=20r/m;

# Limit connections per IP
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

# GeoIP blocking (optional, butuh ngx_http_geoip_module)
# geo $blocked_country {
#     default 0;
#     CN 1;  # China
#     RU 1;  # Russia
# }

server {
    listen 80;
    server_name example.com;

    # ==================================================
    # Security Headers
    # ==================================================
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:;" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

    # ==================================================
    # Block Bad Bots & User Agents
    # ==================================================
    if ($http_user_agent ~* (bot|crawler|spider|scraper|curl|wget|python|nikto|sqlmap)) {
        return 403;
    }
    
    # Block empty user agents
    if ($http_user_agent = "") {
        return 403;
    }

    # ==================================================
    # Block certain request methods
    # ==================================================
    if ($request_method !~ ^(GET|POST|PUT|DELETE|PATCH|OPTIONS)$) {
        return 405;
    }

    # ==================================================
    # Login endpoint - Strict rate limiting
    # ==================================================
    location /login {
        limit_req zone=login burst=2 nodelay;
        limit_conn conn_limit 5;
        
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
    }
    
    # ==================================================
    # Registration endpoint
    # ==================================================
    location /register {
        limit_req zone=login burst=3 nodelay;
        
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
    }

    # ==================================================
    # Search endpoint - Moderate rate limiting
    # ==================================================
    location /search {
        limit_req zone=search burst=10 nodelay;
        
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
    }

    # ==================================================
    # API endpoint - Moderate rate limiting
    # ==================================================
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        
        proxy_pass http://localhost:3000/;
        include /etc/nginx/snippets/proxy-params.conf;
    }

    # ==================================================
    # Admin area - IP whitelist + Basic Auth
    # ==================================================
    location /admin {
        # IP whitelist
        allow 203.0.113.0/24;  # Your office IP range
        allow 198.51.100.10;   # Your home IP
        deny all;
        
        # Basic authentication
        auth_basic "Admin Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
        
        # Rate limiting
        limit_req zone=general burst=10 nodelay;
        
        proxy_pass http://localhost:4000;
        include /etc/nginx/snippets/proxy-params.conf;
    }

    # ==================================================
    # General pages - Normal rate limiting
    # ==================================================
    location / {
        limit_req zone=general burst=50 nodelay;
        limit_conn conn_limit 10;
        
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
    }

    # ==================================================
    # Block access to sensitive files
    # ==================================================
    location ~ /\.(git|env|htaccess|htpasswd|svn|vscode) {
        deny all;
        return 404;
    }

    location ~ \.(sql|bak|backup|log|swp|old)$ {
        deny all;
        return 404;
    }
    
    # ==================================================
    # Block PHP execution in uploads
    # ==================================================
    location ~* ^/uploads/.*\.(php|php5|phtml|pl|py|jsp|asp|sh|cgi)$ {
        deny all;
    }
}
```

### Setup Basic Auth

```bash
# Install htpasswd
sudo apt install -y apache2-utils

# Create password file
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Add more users
sudo htpasswd /etc/nginx/.htpasswd user2

# Verify users
cat /etc/nginx/.htpasswd
```

### Fail2Ban Integration

```bash
# Install fail2ban
sudo apt install -y fail2ban

# Create NGINX jail
sudo nano /etc/fail2ban/jail.local
```

Add:
```ini
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600
findtime = 600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 3600
findtime = 600

[nginx-noscript]
enabled = true
filter = nginx-noscript
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 6
bantime = 86400

[nginx-badbots]
enabled = true
filter = nginx-badbots
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400
```

Create filters:
```bash
# /etc/fail2ban/filter.d/nginx-limit-req.conf
sudo nano /etc/fail2ban/filter.d/nginx-limit-req.conf
```

```ini
[Definition]
failregex = limiting requests, excess:.* by zone.*client: <HOST>
ignoreregex =
```

```bash
# Restart fail2ban
sudo systemctl restart fail2ban

# Check status
sudo fail2ban-client status
sudo fail2ban-client status nginx-http-auth
```

---

## SKENARIO 9: Integrasi Cloudflare

### Use Case
Optimasi NGINX untuk bekerja dengan Cloudflare sebagai CDN dan security layer.

### Cloudflare Setup

#### 1. DNS Configuration
| Type | Name | Content | Proxy | TTL |
|------|------|---------|-------|-----|
| A | example.com | YOUR_SERVER_IP | ✓ (Orange Cloud) | Auto |
| A | www | YOUR_SERVER_IP | ✓ (Orange Cloud) | Auto |
| A | api | YOUR_SERVER_IP | ✓ (Orange Cloud) | Auto |
| A | admin | YOUR_SERVER_IP | ✓ (Orange Cloud) | Auto |

**⚠️ Important:** Orange cloud = Proxied through Cloudflare (recommended)

#### 2. Cloudflare SSL/TLS Settings
- **SSL/TLS encryption mode**: Full (strict) - Recommended
- **Always Use HTTPS**: ON
- **Automatic HTTPS Rewrites**: ON
- **Minimum TLS Version**: TLS 1.2
- **Opportunistic Encryption**: ON
- **TLS 1.3**: ON

#### 3. Cloudflare Page Rules (Optional)
```
# Cache Everything for static subdomain
static.example.com/*
  - Cache Level: Cache Everything
  - Edge Cache TTL: 1 month

# Bypass cache for admin
admin.example.com/*
  - Cache Level: Bypass

# Cache API responses
api.example.com/*
  - Cache Level: Cache Everything
  - Edge Cache TTL: 5 minutes
```

### NGINX Configuration dengan Cloudflare

**File:** `/etc/nginx/sites-available/example.com`

```nginx
# ==================================================
# Cloudflare IP Ranges (Auto-updated list)
# ==================================================
# IPv4
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 104.16.0.0/13;
set_real_ip_from 104.24.0.0/14;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 131.0.72.0/22;

# IPv6
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2a06:98c0::/29;
set_real_ip_from 2c0f:f248::/32;

# Use CF-Connecting-IP header as real IP
real_ip_header CF-Connecting-IP;

server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    # Logs dengan Cloudflare headers
    log_format cloudflare '$http_cf_connecting_ip - $remote_user [$time_local] '
                          '"$request" $status $body_bytes_sent '
                          '"$http_referer" "$http_user_agent" '
                          'CF-Ray: $http_cf_ray '
                          'CF-Country: $http_cf_ipcountry '
                          'CF-Visitor: $http_cf_visitor';

    access_log /var/log/nginx/example.com.access.log cloudflare;
    error_log /var/log/nginx/example.com.error.log;

    # ==================================================
    # Cloudflare Security Headers
    # ==================================================
    # Trust Cloudflare's headers
    proxy_set_header X-Real-IP $http_cf_connecting_ip;
    proxy_set_header X-Forwarded-For $http_cf_connecting_ip;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header CF-RAY $http_cf_ray;
    proxy_set_header CF-Visitor $http_cf_visitor;
    proxy_set_header CF-IPCountry $http_cf_ipcountry;

    # ==================================================
    # Block Direct IP Access (Force through Cloudflare)
    # ==================================================
    if ($http_cf_ray = "") {
        return 403 "Direct IP access not allowed. Please use domain name.";
    }

    # ==================================================
    # Cache Control untuk Cloudflare
    # ==================================================
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
        root /var/www/example.com;
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header CF-Cache-Status $http_cf_cache_status;
        access_log off;
    }

    # ==================================================
    # API dengan Cloudflare caching
    # ==================================================
    location /api/ {
        proxy_pass http://localhost:3000/;
        include /etc/nginx/snippets/proxy-params.conf;
        
        # Cloudflare cache headers
        add_header CF-Cache-Status $http_cf_cache_status;
        
        # Cache-Control untuk Cloudflare CDN
        add_header Cache-Control "public, max-age=300, s-maxage=300";
    }

    # ==================================================
    # Don't cache dynamic content
    # ==================================================
    location ~ ^/(login|logout|admin|cart|checkout) {
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
        
        # Prevent Cloudflare from caching
        add_header Cache-Control "private, no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # ==================================================
    # Main location
    # ==================================================
    location / {
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

### Auto-Update Cloudflare IPs

**File:** `/usr/local/bin/update-cloudflare-ips.sh`

```bash
#!/bin/bash

# Script to automatically update Cloudflare IP ranges in NGINX config
# Run this via cron: 0 3 * * 1 /usr/local/bin/update-cloudflare-ips.sh

NGINX_CONFIG="/etc/nginx/snippets/cloudflare-ips.conf"
TMP_FILE="/tmp/cloudflare-ips.tmp"

echo "# Cloudflare IP Ranges - Auto-generated $(date)" > $TMP_FILE
echo "# Last updated: $(date +%Y-%m-%d)" >> $TMP_FILE
echo "" >> $TMP_FILE

# Download IPv4 ranges
echo "# IPv4 Ranges" >> $TMP_FILE
curl -s https://www.cloudflare.com/ips-v4 | while read ip; do
    echo "set_real_ip_from $ip;" >> $TMP_FILE
done

echo "" >> $TMP_FILE

# Download IPv6 ranges
echo "# IPv6 Ranges" >> $TMP_FILE
curl -s https://www.cloudflare.com/ips-v6 | while read ip; do
    echo "set_real_ip_from $ip;" >> $TMP_FILE
done

echo "" >> $TMP_FILE
echo "# Use Cloudflare header for real IP" >> $TMP_FILE
echo "real_ip_header CF-Connecting-IP;" >> $TMP_FILE

# Backup old config
if [ -f "$NGINX_CONFIG" ]; then
    cp $NGINX_CONFIG ${NGINX_CONFIG}.bak
fi

# Move new config
mv $TMP_FILE $NGINX_CONFIG

# Test NGINX config
if nginx -t 2>&1 | grep -q "test is successful"; then
    echo "✓ Cloudflare IPs updated successfully"
    systemctl reload nginx
    echo "✓ NGINX reloaded"
else
    echo "✗ NGINX config test failed, reverting..."
    mv ${NGINX_CONFIG}.bak $NGINX_CONFIG
    exit 1
fi
```

**Setup:**
```bash
# Make script executable
sudo chmod +x /usr/local/bin/update-cloudflare-ips.sh

# Run once to create initial config
sudo /usr/local/bin/update-cloudflare-ips.sh

# Add to crontab (update every Monday at 3 AM)
sudo crontab -e
# Add: 0 3 * * 1 /usr/local/bin/update-cloudflare-ips.sh
```

**Include in NGINX:**
```nginx
# In your server blocks
include /etc/nginx/snippets/cloudflare-ips.conf;
```

### Cloudflare Origin Certificate

#### 1. Generate Origin Certificate di Cloudflare Dashboard
1. Go to SSL/TLS → Origin Server
2. Click "Create Certificate"
3. Choose: Let Cloudflare generate a private key
4. Validity: 15 years
5. Hostnames: `*.example.com, example.com`
6. Save certificate and private key

#### 2. Install Certificate

```bash
# Create SSL directory
sudo mkdir -p /etc/nginx/ssl/cloudflare

# Save certificate
sudo nano /etc/nginx/ssl/cloudflare/example.com.pem
# Paste certificate content

# Save private key
sudo nano /etc/nginx/ssl/cloudflare/example.com.key
# Paste private key content

# Set permissions
sudo chmod 600 /etc/nginx/ssl/cloudflare/example.com.key
sudo chmod 644 /etc/nginx/ssl/cloudflare/example.com.pem
```

#### 3. NGINX SSL Config

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;
    
    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name example.com www.example.com;

    # Cloudflare Origin Certificate
    ssl_certificate /etc/nginx/ssl/cloudflare/example.com.pem;
    ssl_certificate_key /etc/nginx/ssl/cloudflare/example.com.key;

    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Cloudflare IPs
    include /etc/nginx/snippets/cloudflare-ips.conf;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    
    # Rest of your config...
    location / {
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

### Authenticated Origin Pulls

Untuk extra security, verifikasi bahwa requests datang dari Cloudflare.

#### 1. Download Cloudflare Origin CA

```bash
# Download Cloudflare Origin CA certificate
sudo curl -o /etc/nginx/ssl/cloudflare/origin-pull-ca.pem \
    https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem

# Verify download
openssl x509 -in /etc/nginx/ssl/cloudflare/origin-pull-ca.pem -text -noout
```

#### 2. Enable in Cloudflare Dashboard
1. Go to SSL/TLS → Origin Server
2. Enable "Authenticated Origin Pulls"

#### 3. NGINX Configuration

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    # Your SSL certificates
    ssl_certificate /etc/nginx/ssl/cloudflare/example.com.pem;
    ssl_certificate_key /etc/nginx/ssl/cloudflare/example.com.key;

    # Cloudflare Origin Pull verification
    ssl_client_certificate /etc/nginx/ssl/cloudflare/origin-pull-ca.pem;
    ssl_verify_client on;

    # If verification fails
    error_page 495 496 497 = @no_cloudflare;
    
    location @no_cloudflare {
        return 403 "Direct access not allowed. Must use Cloudflare.";
    }

    location / {
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

### Cloudflare Rate Limiting Integration

Gunakan Cloudflare headers untuk rate limiting yang lebih smart.

```nginx
# Rate limiting based on CF-Connecting-IP
limit_req_zone $http_cf_connecting_ip zone=cf_general:10m rate=10r/s;
limit_req_zone $http_cf_connecting_ip zone=cf_api:10m rate=100r/s;
limit_req_zone $http_cf_connecting_ip zone=cf_login:10m rate=5r/m;

# Rate limiting based on country
map $http_cf_ipcountry $limit_country {
    default         0;
    CN              1;  # China
    RU              1;  # Russia
    # Add more countries as needed
}

limit_req_zone $limit_country zone=country_limit:10m rate=1r/s;

server {
    location /api/ {
        # Apply rate limit
        limit_req zone=cf_api burst=20 nodelay;
        
        # Block certain countries if needed
        if ($limit_country) {
            return 429 "Too many requests from your country";
        }
        
        proxy_pass http://localhost:3000/;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

### Geo-blocking dengan Cloudflare

```nginx
# Block or allow based on country
map $http_cf_ipcountry $allowed_country {
    default         1;
    CN              0;  # Block China
    RU              0;  # Block Russia
    KP              0;  # Block North Korea
}

server {
    # Check country
    if ($allowed_country = 0) {
        return 403 "Access from your country is not allowed";
    }
    
    # Or allow only specific countries for admin
    location /admin {
        set $admin_allowed 0;
        
        if ($http_cf_ipcountry = "US") {
            set $admin_allowed 1;
        }
        if ($http_cf_ipcountry = "ID") {
            set $admin_allowed 1;
        }
        
        if ($admin_allowed = 0) {
            return 403 "Admin access not allowed from your country";
        }
        
        proxy_pass http://localhost:4000;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

### Cloudflare Bot Management

```nginx
# Detect and handle bots using Cloudflare headers
map $http_cf_bot_management $bot_handling {
    default         "allow";
    "verified_bot"  "allow";
    "bot"           "challenge";
    "malicious"     "block";
}

server {
    location / {
        # Block malicious bots
        if ($bot_handling = "block") {
            return 403 "Bot access denied";
        }
        
        # Challenge suspicious bots
        if ($bot_handling = "challenge") {
            # Let Cloudflare handle this
            add_header X-Bot-Score $http_cf_bot_management;
        }
        
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

### Monitoring Cloudflare Integration

```nginx
# Custom log format with Cloudflare data
log_format cloudflare_extended '$http_cf_connecting_ip - $remote_user [$time_local] '
                               '"$request" $status $body_bytes_sent '
                               '"$http_referer" "$http_user_agent" '
                               'CF-Ray: $http_cf_ray '
                               'CF-Country: $http_cf_ipcountry '
                               'CF-Cache: $http_cf_cache_status '
                               'CF-Bot: $http_cf_bot_management '
                               'Request-Time: $request_time';

server {
    access_log /var/log/nginx/cloudflare.access.log cloudflare_extended;
    
    # Monitor Cloudflare cache performance
    location / {
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
        
        # Add Cloudflare cache status to response
        add_header X-CF-Cache-Status $http_cf_cache_status always;
        add_header X-CF-Ray $http_cf_ray always;
    }
}
```

### Testing Cloudflare Integration

```bash
# 1. Test that real IP is being captured
curl -H "CF-Connecting-IP: 1.2.3.4" http://your-server-ip/
# Check logs to see if 1.2.3.4 is logged

# 2. Test Cloudflare headers
curl -I https://example.com/
# Look for CF-Ray, CF-Cache-Status headers

# 3. Test direct IP blocking
curl -I http://YOUR_SERVER_IP/
# Should return 403 if configured correctly

# 4. Test cache status
curl -I https://example.com/static/image.jpg
# Check X-CF-Cache-Status header

# 5. Verify SSL certificate
openssl s_client -connect example.com:443 -servername example.com
# Should show Cloudflare Origin Certificate
```

### Cloudflare Workers Integration (Advanced)

Jika menggunakan Cloudflare Workers, NGINX dapat menerima custom headers:

```nginx
server {
    location /api/ {
        # Headers from Cloudflare Workers
        proxy_set_header X-Worker-ID $http_x_worker_id;
        proxy_set_header X-Worker-Version $http_x_worker_version;
        proxy_set_header X-Custom-Data $http_x_custom_data;
        
        proxy_pass http://localhost:3000/;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

### Complete Cloudflare-Optimized Config

**File:** `/etc/nginx/sites-available/example.com-cloudflare`

```nginx
# ==================================================
# CLOUDFLARE-OPTIMIZED NGINX CONFIGURATION
# ==================================================

# Include Cloudflare IPs
include /etc/nginx/snippets/cloudflare-ips.conf;

# Rate limiting with Cloudflare IPs
limit_req_zone $http_cf_connecting_ip zone=cf_general:10m rate=10r/s;
limit_req_zone $http_cf_connecting_ip zone=cf_api:10m rate=100r/s;

# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;
    return 301 https://$server_name$request_uri;
}

# Main HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name example.com www.example.com;

    # Cloudflare Origin Certificate
    ssl_certificate /etc/nginx/ssl/cloudflare/example.com.pem;
    ssl_certificate_key /etc/nginx/ssl/cloudflare/example.com.key;
    
    # Authenticated Origin Pulls
    ssl_client_certificate /etc/nginx/ssl/cloudflare/origin-pull-ca.pem;
    ssl_verify_client on;

    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # Cloudflare-aware logging
    log_format cloudflare '$http_cf_connecting_ip - $remote_user [$time_local] '
                          '"$request" $status $body_bytes_sent '
                          'CF-Ray:$http_cf_ray Country:$http_cf_ipcountry '
                          'Cache:$http_cf_cache_status';
    
    access_log /var/log/nginx/example.com.access.log cloudflare;
    error_log /var/log/nginx/example.com.error.log;

    # Block direct IP access (force through Cloudflare)
    if ($http_cf_ray = "") {
        return 403 "Direct access denied";
    }

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Static files - aggressive caching for Cloudflare
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
        root /var/www/example.com;
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-CF-Cache-Status $http_cf_cache_status;
        access_log off;
    }

    # API with rate limiting
    location /api/ {
        limit_req zone=cf_api burst=20 nodelay;
        
        proxy_pass http://localhost:3000/;
        include /etc/nginx/snippets/proxy-params.conf;
        
        # Pass Cloudflare headers to backend
        proxy_set_header CF-Ray $http_cf_ray;
        proxy_set_header CF-IPCountry $http_cf_ipcountry;
        proxy_set_header CF-Visitor $http_cf_visitor;
        
        # Cache control for Cloudflare
        add_header Cache-Control "public, max-age=300";
        add_header X-CF-Cache-Status $http_cf_cache_status;
    }

    # Main application
    location / {
        limit_req zone=cf_general burst=50 nodelay;
        
        proxy_pass http://localhost:3000;
        include /etc/nginx/snippets/proxy-params.conf;
        
        # Pass Cloudflare headers
        proxy_set_header CF-Ray $http_cf_ray;
        proxy_set_header CF-IPCountry $http_cf_ipcountry;
    }
}
```

### Troubleshooting Cloudflare Integration

```bash
# 1. Check if Cloudflare IPs are being used
sudo tail -f /var/log/nginx/access.log | grep -v "173.245\|103.21\|103.22"

# 2. Verify real IP is captured
curl -I https://example.com/
# Check access log for correct IP

# 3. Test Cloudflare cache
for i in {1..5}; do
    curl -I https://example.com/static/image.jpg | grep -i "cf-cache-status"
    sleep 1
done

# 4. Check SSL verification
openssl s_client -connect example.com:443 -servername example.com | grep -i cloudflare

# 5. Test direct IP blocking
curl -I http://YOUR_SERVER_IP/
# Should return 403

# 6. Monitor Cloudflare headers
curl -v https://example.com/ 2>&1 | grep -i "cf-"
```

---

## SKENARIO 10: Caching Strategy

### Use Case
Improve performance dengan caching static & dynamic content.

### NGINX Config
**File:** `/etc/nginx/sites-available/example.com`

```nginx
# ==================================================
# Cache Configuration
# ==================================================
proxy_cache_path /var/cache/nginx/api 
    levels=1:2 
    keys_zone=api_cache:10m 
    max_size=1g 
    inactive=60m 
    use_temp_path=off;

proxy_cache_path /var/cache/nginx/static 
    levels=1:2 
    keys_zone=static_cache:10m 
    max_size=2g 
    inactive=7d 
    use_temp_path=off;

# Cache key
proxy_cache_key "$scheme$request_method$host$request_uri";

# Cache valid responses
map $request_method $cache_method {
    GET     "1";
    HEAD    "1";
    default "0";
}

server {
    listen 80;
    server_name example.com;

    # ==================================================
    # API with Caching
    # ==================================================
    location /api/ {
        proxy_pass http://localhost:3000/;
        
        # Caching
        proxy_cache api_cache;
        proxy_cache_valid 200 10m;
        proxy_cache_valid 404 1m;
        proxy_cache_methods GET HEAD;
        proxy_cache_bypass $http_cache_control;
        add_header X-Cache-Status $upstream_cache_status;
        
        # Cache based on auth header
        proxy_cache_key "$scheme$request_method$host$request_uri$http_authorization";
        
        # Headers
        include /etc/nginx/snippets/proxy-params.conf;
    }
    
    # ==================================================
    # Don't cache user-specific endpoints
    # ==================================================
    location ~ ^/api/(auth|user|profile|cart|checkout) {
        proxy_pass http://localhost:3000;
        proxy_no_cache 1;
        proxy_cache_bypass 1;
        
        include /etc/nginx/snippets/proxy-params.conf;
    }

    # ==================================================
    # Static files with aggressive caching
    # ==================================================
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp)$ {
        root /var/www/example.com;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
        
        # Enable Gzip
        gzip_static on;
        gzip_vary on;
    }

    location ~* \.(css|js)$ {
        root /var/www/example.com;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
        
        gzip_static on;
        gzip_vary on;
    }

    # ==================================================
    # HTML with short cache
    # ==================================================
    location ~* \.html$ {
        root /var/www/example.com;
        expires 1h;
        add_header Cache-Control "public, must-revalidate";
    }

    # ==================================================
    # Fonts
    # ==================================================
    location ~* \.(woff|woff2|ttf|eot)$ {
        root /var/www/example.com;
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Access-Control-Allow-Origin *;
        access_log off;
    }
}
```

### Cache Management Commands

```bash
# Create cache directory
sudo mkdir -p /var/cache/nginx/api
sudo mkdir -p /var/cache/nginx/static

# Set permissions
sudo chown -R www-data:www-data /var/cache/nginx
sudo chmod -R 755 /var/cache/nginx

# Clear cache
sudo rm -rf /var/cache/nginx/*

# Check cache size
du -sh /var/cache/nginx/*
```

### Micro-caching for Dynamic Content

```nginx
# Good for high-traffic dynamic sites
location / {
    proxy_pass http://localhost:3000;
    
    # Cache for 1 second
    proxy_cache api_cache;
    proxy_cache_valid 200 1s;
    proxy_cache_lock on;
    proxy_cache_use_stale updating error timeout;
    
    add_header X-Cache-Status $upstream_cache_status;
}
```

---

## SKENARIO 10: Docker & Container Integration

### Use Case
NGINX sebagai reverse proxy untuk Docker containers.

### Docker Compose Setup

**File:** `docker-compose.yml`
```yaml
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./sites:/etc/nginx/conf.d:ro
      - ./ssl:/etc/nginx/ssl:ro
      - ./logs:/var/log/nginx
    depends_on:
      - app
      - api
    networks:
      - webnet
    restart: unless-stopped

  app:
    image: node:18-alpine
    container_name: frontend-app
    working_dir: /app
    volumes:
      - ./app:/app
    command: npm start
    networks:
      - webnet
    restart: unless-stopped

  api:
    image: node:18-alpine
    container_name: backend-api
    working_dir: /app
    volumes:
      - ./api:/app
    command: npm start
    environment:
      - NODE_ENV=production
    networks:
      - webnet
    restart: unless-stopped

networks:
  webnet:
    driver: bridge
```

### NGINX Config for Docker

**File:** `./sites/default.conf`
```nginx
upstream frontend {
    server app:3000;
}

upstream backend {
    server api:5000;
}

server {
    listen 80;
    server_name example.com;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Frontend
    location / {
        proxy_pass http://frontend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend API
    location /api/ {
        proxy_pass http://backend/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Docker Commands

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f nginx

# Reload NGINX config
docker-compose exec nginx nginx -s reload

# Test NGINX config
docker-compose exec nginx nginx -t

# Stop services
docker-compose down
```

---

## SKENARIO 11: Microservices Architecture

### Use Case
Route traffic ke berbagai microservices.

### Contoh
```
example.com/users     → User Service (Port 3001)
example.com/products  → Product Service (Port 3002)
example.com/orders    → Order Service (Port 3003)
example.com/payments  → Payment Service (Port 3004)
```

### NGINX Config
**File:** `/etc/nginx/sites-available/example.com`

```nginx
# ==================================================
# Upstream Services
# ==================================================
upstream user_service {
    least_conn;
    server localhost:3001 max_fails=3 fail_timeout=30s;
    server localhost:3011 backup;
}

upstream product_service {
    least_conn;
    server localhost:3002 max_fails=3 fail_timeout=30s;
    server localhost:3012 backup;
}

upstream order_service {
    least_conn;
    server localhost:3003 max_fails=3 fail_timeout=30s;
    server localhost:3013 backup;
}

upstream payment_service {
    ip_hash;  # Sticky sessions for payment
    server localhost:3004 max_fails=3 fail_timeout=30s;
    server localhost:3014 backup;
}

# ==================================================
# Rate Limiting Zones
# ==================================================
limit_req_zone $binary_remote_addr zone=users:10m rate=100r/s;
limit_req_zone $binary_remote_addr zone=products:10m rate=200r/s;
limit_req_zone $binary_remote_addr zone=orders:10m rate=50r/s;
limit_req_zone $binary_remote_addr zone=payments:10m rate=10r/s;

server {
    listen 80;
    server_name example.com;

    access_log /var/log/nginx/microservices.access.log;
    error_log /var/log/nginx/microservices.error.log;

    # ==================================================
    # User Service
    # ==================================================
    location /users {
        limit_req zone=users burst=50 nodelay;
        
        proxy_pass http://user_service;
        include /etc/nginx/snippets/proxy-params.conf;
        
        # Service-specific headers
        proxy_set_header X-Service "user-service";
        
        # Timeouts
        proxy_connect_timeout 5s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }

    # ==================================================
    # Product Service
    # ==================================================
    location /products {
        limit_req zone=products burst=100 nodelay;
        
        proxy_pass http://product_service;
        include /etc/nginx/snippets/proxy-params.conf;
        
        proxy_set_header X-Service "product-service";
        
        # Cache product listings
        proxy_cache api_cache;
        proxy_cache_valid 200 5m;
        add_header X-Cache-Status $upstream_cache_status;
    }

    # ==================================================
    # Order Service
    # ==================================================
    location /orders {
        limit_req zone=orders burst=20 nodelay;
        
        proxy_pass http://order_service;
        include /etc/nginx/snippets/proxy-params.conf;
        
        proxy_set_header X-Service "order-service";
        
        # No caching for orders
        proxy_no_cache 1;
        proxy_cache_bypass 1;
    }

    # ==================================================
    # Payment Service - Extra Security
    # ==================================================
    location /payments {
        limit_req zone=payments burst=5 nodelay;
        
        # Only allow POST requests
        if ($request_method !~ ^(POST)$) {
            return 405;
        }
        
        proxy_pass http://payment_service;
        include /etc/nginx/snippets/proxy-params.conf;
        
        proxy_set_header X-Service "payment-service";
        
        # Extended timeouts for payment processing
        proxy_connect_timeout 10s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # No caching
        proxy_no_cache 1;
        proxy_cache_bypass 1;
    }

    # ==================================================
    # Health Check Endpoint
    # ==================================================
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # ==================================================
    # Service Status Dashboard
    # ==================================================
    location /status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        deny all;
    }
}
```

### Circuit Breaker Pattern

```nginx
# Upstream with health checks
upstream api_service {
    server localhost:3000 max_fails=3 fail_timeout=30s;
    server localhost:3001 max_fails=3 fail_timeout=30s;
}

server {
    location /api/ {
        proxy_pass http://api_service;
        
        # Auto-retry on failure
        proxy_next_upstream error timeout http_500 http_502 http_503;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 10s;
        
        # Return 503 if all backends fail
        error_page 502 503 504 = @fallback;
    }
    
    location @fallback {
        return 503 '{"error": "Service temporarily unavailable"}';
        add_header Content-Type application/json;
    }
}
```

---

## SKENARIO 12: Blue-Green Deployment

### Use Case
Zero-downtime deployment dengan switching antara blue/green environments.

### NGINX Config
**File:** `/etc/nginx/sites-available/example.com`

```nginx
# ==================================================
# Blue-Green Upstream Configuration
# ==================================================
upstream backend_blue {
    server localhost:3000 max_fails=3 fail_timeout=30s;
    server localhost:3001 max_fails=3 fail_timeout=30s;
}

upstream backend_green {
    server localhost:4000 max_fails=3 fail_timeout=30s;
    server localhost:4001 max_fails=3 fail_timeout=30s;
}

# Current active environment (change this for switching)
upstream backend_active {
    server localhost:3000 max_fails=3 fail_timeout=30s;
    server localhost:3001 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name example.com;

    # ==================================================
    # Production Traffic (Active Environment)
    # ==================================================
    location / {
        proxy_pass http://backend_active;
        include /etc/nginx/snippets/proxy-params.conf;
    }

    # ==================================================
    # Blue Environment (for testing)
    # ==================================================
    location /blue/ {
        # Only accessible from specific IPs
        allow 10.0.0.0/8;
        deny all;
        
        proxy_pass http://backend_blue/;
        include /etc/nginx/snippets/proxy-params.conf;
    }

    # ==================================================
    # Green Environment (for testing)
    # ==================================================
    location /green/ {
        # Only accessible from specific IPs
        allow 10.0.0.0/8;
        deny all;
        
        proxy_pass http://backend_green/;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

### Deployment Script

**File:** `deploy.sh`
```bash
#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

CURRENT_ENV=$(grep -A 2 "upstream backend_active" /etc/nginx/sites-available/example.com | grep "server" | awk '{print $2}' | cut -d':' -f2)

if [ "$CURRENT_ENV" == "3000" ]; then
    echo -e "${BLUE}Current: BLUE${NC}"
    echo -e "${GREEN}Switching to: GREEN${NC}"
    NEW_PORT="4000"
    NEW_ENV="GREEN"
else
    echo -e "${GREEN}Current: GREEN${NC}"
    echo -e "${BLUE}Switching to: BLUE${NC}"
    NEW_PORT="3000"
    NEW_ENV="BLUE"
fi

# Update NGINX config
sudo sed -i "/upstream backend_active/,/}/ s/server localhost:[0-9]*/server localhost:$NEW_PORT/" /etc/nginx/sites-available/example.com

# Test config
if sudo nginx -t; then
    echo "✓ NGINX config test passed"
    sudo systemctl reload nginx
    echo -e "✓ Switched to ${NEW_ENV} environment"
else
    echo "✗ NGINX config test failed"
    exit 1
fi
```

### Canary Deployment (Advanced)

```nginx
# Split traffic: 90% to stable, 10% to canary
split_clients $remote_addr $backend_variant {
    10%     canary;
    *       stable;
}

upstream backend_stable {
    server localhost:3000;
}

upstream backend_canary {
    server localhost:4000;
}

server {
    location / {
        proxy_pass http://backend_$backend_variant;
        include /etc/nginx/snippets/proxy-params.conf;
        add_header X-Backend-Version $backend_variant;
    }
}
```

---

## PERFORMANCE OPTIMIZATION

### 1. NGINX Main Config Optimization

**File:** `/etc/nginx/nginx.conf`

```nginx
user www-data;
worker_processes auto;  # Auto-detect CPU cores
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;  # Efficient for Linux
    multi_accept on;
}

http {
    ##
    # Basic Settings
    ##
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 100;
    types_hash_max_size 2048;
    server_tokens off;  # Hide NGINX version
    
    # Buffer size optimization
    client_body_buffer_size 128k;
    client_max_body_size 100m;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 16k;
    output_buffers 1 32k;
    postpone_output 1460;

    ##
    # Mime Types
    ##
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    ##
    # Gzip Compression
    ##
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/rss+xml
        font/truetype
        font/opentype
        application/vnd.ms-fontobject
        image/svg+xml;
    gzip_disable "msie6";
    gzip_min_length 256;

    ##
    # Brotli Compression (if module installed)
    ##
    # brotli on;
    # brotli_comp_level 6;
    # brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    ##
    # Open File Cache
    ##
    open_file_cache max=10000 inactive=30s;
    open_file_cache_valid 60s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;

    ##
    # Logging Settings
    ##
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log main buffer=32k flush=5s;
    error_log /var/log/nginx/error.log warn;

    ##
    # Virtual Host Configs
    ##
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

### 2. FastCGI Caching (for PHP apps)

```nginx
# FastCGI cache configuration
fastcgi_cache_path /var/cache/nginx/fastcgi 
    levels=1:2 
    keys_zone=fastcgi_cache:100m 
    inactive=60m 
    max_size=1g;

server {
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        
        # Caching
        fastcgi_cache fastcgi_cache;
        fastcgi_cache_valid 200 60m;
        fastcgi_cache_methods GET HEAD;
        fastcgi_cache_bypass $skip_cache;
        fastcgi_no_cache $skip_cache;
        
        add_header X-FastCGI-Cache $upstream_cache_status;
    }
    
    # Skip cache for certain conditions
    set $skip_cache 0;
    
    # POST requests skip cache
    if ($request_method = POST) {
        set $skip_cache 1;
    }
    
    # URLs with query strings skip cache
    if ($query_string != "") {
        set $skip_cache 1;
    }
    
    # Don't cache admin/login pages
    if ($request_uri ~* "/wp-admin/|/wp-login.php|/admin|/login") {
        set $skip_cache 1;
    }
}
```

### 3. HTTP/2 Push

```nginx
server {
    listen 443 ssl http2;
    
    location = /index.html {
        http2_push /css/style.css;
        http2_push /js/app.js;
        http2_push /images/logo.png;
    }
}
```

### 4. Connection Pooling

```nginx
upstream backend {
    server localhost:3000;
    
    # Keep connections alive
    keepalive 32;
    keepalive_timeout 60s;
    keepalive_requests 100;
}

server {
    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";  # Clear Connection header
    }
}
```

---

## MONITORING & LOGGING

### 1. NGINX Status Module

```nginx
server {
    listen 8080;
    server_name localhost;
    
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        deny all;
    }
}
```

Access: `curl http://localhost:8080/nginx_status`

### 2. Custom Log Format dengan Timing

```nginx
log_format detailed '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    'rt=$request_time '
                    'uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" '
                    'urt="$upstream_response_time" '
                    'cache="$upstream_cache_status"';

access_log /var/log/nginx/access.log detailed;
```

### 3. Error Logging Levels

```nginx
# error_log levels: debug, info, notice, warn, error, crit, alert, emerg
error_log /var/log/nginx/error.log warn;

# Debug specific location
location /api/ {
    error_log /var/log/nginx/api-debug.log debug;
    proxy_pass http://backend;
}
```

### 4. Log Rotation

**File:** `/etc/logrotate.d/nginx`
```
/var/log/nginx/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    prerotate
        if [ -d /etc/logrotate.d/httpd-prerotate ]; then \
            run-parts /etc/logrotate.d/httpd-prerotate; \
        fi
    endscript
    postrotate
        invoke-rc.d nginx rotate >/dev/null 2>&1
    endscript
}
```

### 5. Prometheus Metrics (with nginx-prometheus-exporter)

```bash
# Install exporter
wget https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v0.11.0/nginx-prometheus-exporter_0.11.0_linux_amd64.tar.gz
tar xzf nginx-prometheus-exporter_0.11.0_linux_amd64.tar.gz
sudo mv nginx-prometheus-exporter /usr/local/bin/

# Run exporter
nginx-prometheus-exporter -nginx.scrape-uri=http://localhost:8080/nginx_status
```

### 6. Real-time Log Monitoring

```bash
# Watch access log
tail -f /var/log/nginx/access.log

# Watch error log
tail -f /var/log/nginx/error.log

# Watch specific site
tail -f /var/log/nginx/example.com.access.log

# Filter 4xx errors
tail -f /var/log/nginx/access.log | grep " 4[0-9][0-9] "

# Filter 5xx errors
tail -f /var/log/nginx/access.log | grep " 5[0-9][0-9] "

# Show slow requests (> 1 second)
tail -f /var/log/nginx/access.log | awk '$NF > 1.0'

# Count requests per minute
tail -f /var/log/nginx/access.log | pv -l -i 1 -r > /dev/null
```

---

## TROUBLESHOOTING

### Common Issues & Solutions

#### 1. 502 Bad Gateway
```bash
# Check if backend is running
sudo netstat -tlnp | grep :3000

# Check backend logs
journalctl -u your-app-service -f

# Check NGINX error log
sudo tail -f /var/log/nginx/error.log

# Test backend directly
curl http://localhost:3000

# Solution: Make sure backend is running and accessible
```

#### 2. 504 Gateway Timeout
```nginx
# Increase timeouts in NGINX config
location / {
    proxy_pass http://backend;
    proxy_connect_timeout 600s;
    proxy_send_timeout 600s;
    proxy_read_timeout 600s;
}
```

#### 3. 413 Request Entity Too Large
```nginx
# Increase client body size
http {
    client_max_body_size 100M;
}
```

#### 4. SSL Certificate Issues
```bash
# Check certificate
sudo certbot certificates

# Renew certificate
sudo certbot renew --dry-run
sudo certbot renew

# Test SSL configuration
openssl s_client -connect example.com:443 -servername example.com

# Check SSL rating
# Visit: https://www.ssllabs.com/ssltest/
```

#### 5. WebSocket Connection Issues
```nginx
# Ensure WebSocket headers are set
location /ws {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # Long timeouts for WebSocket
    proxy_read_timeout 86400;
}
```

#### 6. CORS Issues
```nginx
# Add CORS headers
location /api/ {
    if ($request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Origin' '*';
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type';
        add_header 'Access-Control-Max-Age' 1728000;
        add_header 'Content-Type' 'text/plain charset=UTF-8';
        add_header 'Content-Length' 0;
        return 204;
    }
    
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;
    
    proxy_pass http://backend/;
}
```

#### 7. High Memory Usage
```bash
# Check NGINX memory usage
ps aux | grep nginx

# Reduce worker_connections
# Edit /etc/nginx/nginx.conf
events {
    worker_connections 1024;  # Reduce from 4096
}

# Disable access logs for high-traffic sites
access_log off;
```

#### 8. Config Test Fails
```bash
# Test config syntax
sudo nginx -t

# Test and show full config
sudo nginx -T

# Common issues:
# - Missing semicolon
# - Duplicate server_name
# - Wrong file paths
# - Syntax errors in regex
```

### Debugging Tools

#### 1. Test Backend Connection
```bash
# Test HTTP connection
curl -v http://localhost:3000

# Test with headers
curl -H "Host: example.com" http://localhost:3000

# Test WebSocket
wscat -c ws://localhost:3000/ws
```

#### 2. Check NGINX Process
```bash
# Check if NGINX is running
sudo systemctl status nginx

# Check NGINX process
ps aux | grep nginx

# Check port binding
sudo netstat -tlnp | grep nginx
sudo ss -tlnp | grep nginx
```

#### 3. Analyze Logs
```bash
# Find errors
sudo grep "error" /var/log/nginx/error.log

# Find 5xx errors
sudo grep " 50[0-9] " /var/log/nginx/access.log

# Count requests by status code
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn

# Find slowest requests
awk '{print $NF, $0}' /var/log/nginx/access.log | sort -rn | head -20

# Find most requested URLs
awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20

# Find top IPs
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20
```

#### 4. Performance Testing
```bash
# Apache Bench
ab -n 1000 -c 10 http://example.com/

# wrk (more advanced)
wrk -t4 -c100 -d30s http://example.com/

# siege
siege -c 50 -t 1M http://example.com/
```

---

## BEST PRACTICES & TIPS

### 1. File Structure Organization

```
/etc/nginx/
├── nginx.conf                      # Main config
├── sites-available/                # All site configs
│   ├── example.com
│   ├── app.example.com
│   ├── api.example.com
│   └── admin.example.com
├── sites-enabled/                  # Enabled sites (symlinks)
│   ├── example.com -> ../sites-available/example.com
│   └── app.example.com -> ../sites-available/app.example.com
├── snippets/                       # Reusable config snippets
│   ├── ssl-params.conf
│   ├── proxy-params.conf
│   ├── security-headers.conf
│   └── cache-params.conf
├── conf.d/                         # Additional configs
│   ├── rate-limiting.conf
│   └── upstream.conf
├── ssl/                            # SSL certificates
│   ├── dhparam.pem
│   └── example.com/
└── logs/                           # Symbolic link to /var/log/nginx/
```

### 2. Reusable Snippets

**File:** `/etc/nginx/snippets/proxy-params.conf`
```nginx
proxy_http_version 1.1;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header Connection "";
proxy_buffering off;

# Timeouts
proxy_connect_timeout 60s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;
```

**File:** `/etc/nginx/snippets/security-headers.conf`
```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
```

**File:** `/etc/nginx/snippets/ssl-params.conf`
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
```

**File:** `/etc/nginx/snippets/cache-params.conf`
```nginx
proxy_cache_valid 200 10m;
proxy_cache_valid 404 1m;
proxy_cache_methods GET HEAD;
proxy_cache_bypass $http_cache_control;
proxy_no_cache $http_pragma $http_authorization;
add_header X-Cache-Status $upstream_cache_status;
```

**Usage:**
```nginx
server {
    location / {
        include /etc/nginx/snippets/proxy-params.conf;
        include /etc/nginx/snippets/security-headers.conf;
        proxy_pass http://backend;
    }
}
```

### 3. Version Control for Configs

```bash
# Initialize git repo
cd /etc/nginx
sudo git init
sudo git add .
sudo git commit -m "Initial NGINX configuration"

# Before making changes
sudo git status
sudo git diff

# After making changes
sudo git add .
sudo git commit -m "Added new site configuration for api.example.com"

# View history
sudo git log --oneline

# Rollback if needed
sudo git checkout HEAD~1 sites-available/example.com
```

### 4. Testing Before Deploy

```bash
# Always test before reload
sudo nginx -t && sudo systemctl reload nginx

# Create test script
cat > ~/nginx-test.sh << 'EOF'
#!/bin/bash
echo "Testing NGINX configuration..."
if sudo nginx -t 2>&1 | grep -q "test is successful"; then
    echo "✓ Config test passed"
    echo "Reloading NGINX..."
    sudo systemctl reload nginx
    echo "✓ NGINX reloaded successfully"
else
    echo "✗ Config test failed"
    sudo nginx -t
    exit 1
fi
EOF

chmod +x ~/nginx-test.sh
```

### 5. Backup Strategy

```bash
# Create backup script
cat > ~/nginx-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/nginx"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup configs
sudo tar czf $BACKUP_DIR/nginx-config-$DATE.tar.gz \
    /etc/nginx/nginx.conf \
    /etc/nginx/sites-available/ \
    /etc/nginx/sites-enabled/ \
    /etc/nginx/snippets/ \
    /etc/nginx/conf.d/

# Backup SSL certificates
sudo tar czf $BACKUP_DIR/nginx-ssl-$DATE.tar.gz \
    /etc/letsencrypt/ \
    /etc/nginx/ssl/

# Keep only last 7 backups
ls -t $BACKUP_DIR/nginx-config-*.tar.gz | tail -n +8 | xargs -r rm
ls -t $BACKUP_DIR/nginx-ssl-*.tar.gz | tail -n +8 | xargs -r rm

echo "✓ Backup completed: $BACKUP_DIR/nginx-config-$DATE.tar.gz"
EOF

chmod +x ~/nginx-backup.sh

# Add to crontab (daily backup at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /home/$(whoami)/nginx-backup.sh") | crontab -
```

### 6. Security Checklist

```nginx
# ✓ Hide NGINX version
server_tokens off;

# ✓ Use strong SSL/TLS configuration
ssl_protocols TLSv1.2 TLSv1.3;

# ✓ Enable HSTS
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# ✓ Implement rate limiting
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;

# ✓ Block bad bots
if ($http_user_agent ~* (bot|crawler|spider)) {
    return 403;
}

# ✓ Restrict access to admin areas
location /admin {
    allow 10.0.0.0/8;
    deny all;
    auth_basic "Admin Area";
    auth_basic_user_file /etc/nginx/.htpasswd;
}

# ✓ Prevent clickjacking
add_header X-Frame-Options "SAMEORIGIN" always;

# ✓ Prevent MIME sniffing
add_header X-Content-Type-Options "nosniff" always;

# ✓ Enable XSS protection
add_header X-XSS-Protection "1; mode=block" always;

# ✓ Deny access to hidden files
location ~ /\. {
    deny all;
}

# ✓ Limit upload size
client_max_body_size 10M;
```

### 7. Performance Checklist

```nginx
# ✓ Enable gzip compression
gzip on;
gzip_vary on;
gzip_comp_level 6;
gzip_types text/plain text/css application/json application/javascript;

# ✓ Enable open file cache
open_file_cache max=10000 inactive=30s;
open_file_cache_valid 60s;

# ✓ Use HTTP/2
listen 443 ssl http2;

# ✓ Enable keepalive connections
keepalive_timeout 65;
keepalive_requests 100;

# ✓ Optimize worker processes
worker_processes auto;
worker_connections 4096;

# ✓ Enable sendfile
sendfile on;
tcp_nopush on;
tcp_nodelay on;

# ✓ Implement caching
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=cache:10m;

# ✓ Use connection pooling for upstreams
upstream backend {
    server localhost:3000;
    keepalive 32;
}
```

### 8. Maintenance Commands

```bash
# Start NGINX
sudo systemctl start nginx

# Stop NGINX
sudo systemctl stop nginx

# Restart NGINX (brief downtime)
sudo systemctl restart nginx

# Reload config (zero downtime)
sudo systemctl reload nginx

# Test config
sudo nginx -t

# View full config
sudo nginx -T

# Check NGINX version
nginx -v
nginx -V  # with compile options

# Enable site
sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/

# Disable site
sudo rm /etc/nginx/sites-enabled/example.com

# View active connections
curl http://localhost:8080/nginx_status

# Check syntax of specific file
sudo nginx -t -c /etc/nginx/sites-available/example.com
```

### 9. Documentation Template

**File:** `/etc/nginx/sites-available/example.com`
```nginx
# ==========================================================
# SITE: example.com
# CREATED: 2025-01-01
# UPDATED: 2025-01-15
# AUTHOR: Your Name
# DESCRIPTION: Main production site for Example Corp
# DEPENDENCIES: 
#   - Backend API running on localhost:3000
#   - Redis cache on localhost:6379
# ==========================================================

# Backend upstream
upstream backend_api {
    server localhost:3000 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

server {
    # Basic Configuration
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    # Logging
    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;

    # Security headers
    include /etc/nginx/snippets/security-headers.conf;

    # Main application
    location / {
        proxy_pass http://backend_api;
        include /etc/nginx/snippets/proxy-params.conf;
    }
}
```

### 10. Quick Reference Commands

```bash
# ==================================================
# BASIC OPERATIONS
# ==================================================
sudo nginx -t                    # Test config
sudo systemctl reload nginx      # Reload (recommended)
sudo systemctl restart nginx     # Restart (if reload fails)
sudo systemctl status nginx      # Check status

# ==================================================
# LOGS
# ==================================================
sudo tail -f /var/log/nginx/error.log              # Watch error log
sudo tail -f /var/log/nginx/access.log             # Watch access log
sudo tail -f /var/log/nginx/example.com.error.log  # Site-specific

# ==================================================
# TROUBLESHOOTING
# ==================================================
sudo nginx -T                    # Show full config
curl -I http://localhost         # Test locally
curl -I http://example.com       # Test publicly
sudo netstat -tlnp | grep nginx  # Check ports

# ==================================================
# SSL/HTTPS
# ==================================================
sudo certbot --nginx -d example.com              # Get certificate
sudo certbot renew                               # Renew certificates
sudo certbot certificates                        # List certificates
openssl s_client -connect example.com:443        # Test SSL

# ==================================================
# PERFORMANCE
# ==================================================
ab -n 1000 -c 10 http://example.com/            # Benchmark
curl http://localhost:8080/nginx_status         # Check stats
sudo systemctl reload nginx                      # Zero-downtime reload

# ==================================================
# SECURITY
# ==================================================
sudo htpasswd -c /etc/nginx/.htpasswd admin     # Create basic auth
sudo fail2ban-client status nginx-http-auth     # Check fail2ban
sudo iptables -L -n                             # Check firewall
```

---

## CHEAT SHEET

### Common Directives

```nginx
# Server Block
server {
    listen 80;                          # IPv4
    listen [::]:80;                     # IPv6
    listen 443 ssl http2;               # HTTPS with HTTP/2
    server_name example.com;            # Domain name
    root /var/www/html;                 # Document root
    index index.html;                   # Default file
}

# Location Block
location / { }                          # Exact match
location = /path { }                    # Exact match only
location ~ \.php$ { }                   # Regex match (case-sensitive)
location ~* \.(jpg|png)$ { }           # Regex (case-insensitive)
location ^~ /images/ { }                # Prefix match (stops regex)

# Proxy
proxy_pass http://backend;              # Forward to backend
proxy_set_header Host $host;            # Pass Host header
proxy_set_header X-Real-IP $remote_addr; # Pass client IP

# SSL
ssl_certificate /path/to/cert.pem;      # Certificate
ssl_certificate_key /path/to/key.pem;   # Private key
ssl_protocols TLSv1.2 TLSv1.3;         # Allowed protocols

# Caching
proxy_cache my_cache;                   # Enable cache
proxy_cache_valid 200 10m;              # Cache 200 responses for 10 min
proxy_cache_bypass $http_cache_control; # Skip cache if requested

# Rate Limiting
limit_req_zone $binary_remote_addr zone=one:10m rate=10r/s;
limit_req zone=one burst=20 nodelay;

# Redirects
return 301 https://$server_name$request_uri;  # Permanent redirect
rewrite ^/old$ /new permanent;                 # Rewrite with redirect

# Try Files
try_files $uri $uri/ /index.html;       # Try file, dir, fallback

# Headers
add_header X-Custom-Header "value";     # Add response header
proxy_set_header X-Custom "value";      # Add request header

# Access Control
allow 192.168.1.0/24;                   # Allow IP range
deny all;                               # Deny all others
auth_basic "Restricted";                # Enable basic auth
auth_basic_user_file /etc/nginx/.htpasswd;
```

### Variables

```nginx
$remote_addr                # Client IP
$request_uri                # Full request URI
$uri                        # Current URI (no args)
$args                       # Query string arguments
$host                       # Host header
$scheme                     # http or https
$server_name                # Server name from config
$request_method             # GET, POST, etc.
$http_user_agent            # User agent string
$http_referer               # Referer header
$upstream_cache_status      # Cache hit/miss status
$request_time               # Request processing time
$upstream_response_time     # Backend response time
```

---

## CONCLUSION

Panduan ini mencakup hampir semua skenario umum penggunaan NGINX:

✅ **Single & Multiple Domains** - Konfigurasi basic hingga complex  
✅ **Load Balancing** - Distribusi traffic ke multiple servers  
✅ **SSL/HTTPS** - Security dengan Let's Encrypt  
✅ **WebSocket** - Real-time applications  
✅ **Rate Limiting** - Protection dari abuse  
✅ **Caching** - Performance optimization  
✅ **Docker Integration** - Container orchestration  
✅ **Microservices** - Service mesh architecture  
✅ **Blue-Green Deployment** - Zero-downtime releases  
✅ **Monitoring & Logging** - Observability  
✅ **Troubleshooting** - Problem solving  
✅ **Best Practices** - Production-ready configurations  

### Next Steps

1. **Pilih skenario** yang sesuai dengan kebutuhan Anda
2. **Copy & customize** konfigurasi yang diperlukan
3. **Test** dengan `nginx -t` sebelum deploy
4. **Monitor** logs dan performance
5. **Iterate** berdasarkan feedback dan metrics

### Useful Resources

- **Official Docs**: https://nginx.org/en/docs/
- **SSL Test**: https://www.ssllabs.com/ssltest/
- **Config Generator**: https://nginxconfig.io/
- **Community**: https://forum.nginx.org/

---

**💡 Pro Tip**: Selalu backup konfigurasi sebelum melakukan perubahan major, dan gunakan version control (git) untuk tracking changes!

**🔒 Security Tip**: Jangan expose sensitive information di config files, dan selalu gunakan SSL/HTTPS untuk production!

**⚡ Performance Tip**: Enable caching, gzip compression, dan HTTP/2 untuk performance optimal!
