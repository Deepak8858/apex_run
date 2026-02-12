#!/bin/bash
set -e

# ApexRun SSL Setup Script
# Run this on the Droplet AFTER pointing DNS to the server IP
#
# Prerequisites:
#   1. DNS A record: api.apexrun.app → 143.110.183.106
#   2. DNS propagation complete (check: dig api.apexrun.app)
#   3. Backend already running on port 8080

DOMAIN="api.apexrun.app"
EMAIL="deepak8858@gmail.com"
PROJECT_DIR="/root/apex_run"
COMPOSE_FILE="docker-compose.prod.yml"

echo "🔒 ApexRun SSL Setup"
echo "===================="
echo ""
echo "Domain: ${DOMAIN}"
echo ""

# ─── Step 1: Verify DNS ───────────────────────────────────────────
echo "📡 Step 1: Verifying DNS resolution..."
RESOLVED_IP=$(dig +short ${DOMAIN} A 2>/dev/null || true)
DROPLET_IP=$(curl -s http://ifconfig.me)

if [ -z "$RESOLVED_IP" ]; then
    echo "❌ DNS not resolving for ${DOMAIN}"
    echo "   Please add an A record pointing to: ${DROPLET_IP}"
    echo ""
    echo "   In your DNS provider (e.g., DigitalOcean DNS, Cloudflare, etc.):"
    echo "   Type: A"
    echo "   Name: api"
    echo "   Value: ${DROPLET_IP}"
    echo ""
    echo "Re-run this script after DNS propagates (usually 5-30 minutes)."
    exit 1
fi

if [ "$RESOLVED_IP" != "$DROPLET_IP" ]; then
    echo "⚠️  DNS resolves to ${RESOLVED_IP}, but this Droplet's IP is ${DROPLET_IP}"
    echo "   Update your DNS A record to point to: ${DROPLET_IP}"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ DNS resolves correctly: ${DOMAIN} → ${RESOLVED_IP}"
fi

# ─── Step 2: Make IPv6 persistent ────────────────────────────────
echo ""
echo "🌐 Step 2: Making IPv6 persistent..."
IPV6_ADDR="2400:6180:100:d0:0:1:1015:7001/128"
IPV6_GW="2400:6180:100:d0::1"

# Check if IPv6 is already assigned
if ip -6 addr show dev eth0 | grep -q "2400:6180"; then
    echo "✅ IPv6 already configured on eth0"
else
    echo "   Adding IPv6 address..."
    ip -6 addr add ${IPV6_ADDR} dev eth0 2>/dev/null || true
    ip -6 route add default via ${IPV6_GW} dev eth0 2>/dev/null || true
fi

# Persist via netplan
if [ ! -f /etc/netplan/60-ipv6.yaml ]; then
    echo "   Creating netplan config for IPv6 persistence..."
    cat > /etc/netplan/60-ipv6.yaml << EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - ${IPV6_ADDR}
      routes:
        - to: "::/0"
          via: "${IPV6_GW}"
EOF
    chmod 600 /etc/netplan/60-ipv6.yaml
    netplan apply 2>/dev/null || true
    echo "✅ IPv6 persisted via netplan"
else
    echo "✅ IPv6 netplan config already exists"
fi

# ─── Step 3: Install certbot ─────────────────────────────────────
echo ""
echo "📦 Step 3: Installing certbot..."
if command -v certbot &> /dev/null; then
    echo "✅ certbot already installed"
else
    apt-get update -qq
    apt-get install -y certbot
    echo "✅ certbot installed"
fi

# ─── Step 4: Stop nginx if running ───────────────────────────────
echo ""
echo "🛑 Step 4: Ensuring port 80 is free..."
cd ${PROJECT_DIR}

# Stop nginx container if it's running (it would hold port 80)
docker stop apexrun_nginx 2>/dev/null || true
docker rm apexrun_nginx 2>/dev/null || true

# Also stop any system nginx
systemctl stop nginx 2>/dev/null || true

# Check port 80 is free
if ss -tlnp | grep -q ':80 '; then
    echo "⚠️  Port 80 is still in use:"
    ss -tlnp | grep ':80 '
    echo "   Please free port 80 and re-run this script"
    exit 1
fi
echo "✅ Port 80 is free"

# ─── Step 5: Get SSL certificate ─────────────────────────────────
echo ""
echo "🔐 Step 5: Obtaining SSL certificate from Let's Encrypt..."

if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
    echo "✅ SSL certificate already exists"
    echo "   Expiry: $(openssl x509 -enddate -noout -in /etc/letsencrypt/live/${DOMAIN}/fullchain.pem)"
else
    certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email ${EMAIL} \
        -d ${DOMAIN} \
        --preferred-challenges http

    if [ $? -eq 0 ]; then
        echo "✅ SSL certificate obtained successfully!"
    else
        echo "❌ Failed to obtain certificate. Check:"
        echo "   - DNS is pointing to this server"
        echo "   - Port 80 is accessible from the internet"
        echo "   - No firewall blocking port 80"
        exit 1
    fi
fi

# ─── Step 6: Create certbot webroot dir ──────────────────────────
echo ""
echo "📁 Step 6: Setting up certbot webroot..."
mkdir -p /var/lib/docker/volumes/apex_run_certbot_webroot/_data
echo "✅ Certbot webroot ready"

# ─── Step 7: Start nginx with SSL ────────────────────────────────
echo ""
echo "🚀 Step 7: Starting nginx with SSL..."
cd ${PROJECT_DIR}

# Pull latest code
git pull origin main 2>/dev/null || true

# Rebuild and start everything
docker-compose -f ${COMPOSE_FILE} up -d --build

# Wait for nginx
echo "⏳ Waiting for nginx to start..."
sleep 5

# Check if nginx is running
if docker ps | grep -q apexrun_nginx; then
    echo "✅ Nginx is running!"
else
    echo "❌ Nginx failed to start. Checking logs..."
    docker logs apexrun_nginx 2>&1 | tail -20
    exit 1
fi

# ─── Step 8: Setup cert auto-renewal ─────────────────────────────
echo ""
echo "🔄 Step 8: Setting up automatic certificate renewal..."

# Create renewal hook to reload nginx
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh << 'EOF'
#!/bin/bash
# Reload nginx after certificate renewal
docker exec apexrun_nginx nginx -s reload 2>/dev/null || true
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

# Add cron job for renewal (runs twice daily as recommended)
if ! crontab -l 2>/dev/null | grep -q certbot; then
    (crontab -l 2>/dev/null; echo "0 3,15 * * * certbot renew --quiet") | crontab -
    echo "✅ Auto-renewal cron job added (runs at 3:00 AM and 3:00 PM)"
else
    echo "✅ Auto-renewal cron job already exists"
fi

# ─── Step 9: Test everything ─────────────────────────────────────
echo ""
echo "🧪 Step 9: Testing endpoints..."

# Test HTTP redirect
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${DOMAIN}/health 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "301" ]; then
    echo "✅ HTTP → HTTPS redirect working (301)"
elif [ "$HTTP_CODE" = "200" ]; then
    echo "✅ HTTP endpoint responding (200)"
else
    echo "⚠️  HTTP test returned: ${HTTP_CODE}"
fi

# Test HTTPS
HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://${DOMAIN}/health 2>/dev/null || echo "000")
if [ "$HTTPS_CODE" = "200" ]; then
    echo "✅ HTTPS endpoint working (200)"
    echo ""
    echo "   Health check response:"
    curl -s https://${DOMAIN}/health | python3 -m json.tool 2>/dev/null || curl -s https://${DOMAIN}/health
else
    echo "⚠️  HTTPS test returned: ${HTTPS_CODE}"
    echo "   This might be because DNS hasn't fully propagated yet."
    echo "   Try: curl -k https://${DOMAIN}/health"
fi

# ─── Done ─────────────────────────────────────────────────────────
echo ""
echo ""
echo "✨ SSL Setup Complete!"
echo "========================================"
echo ""
echo "🌐 Your API is now available at:"
echo "   https://${DOMAIN}"
echo "   https://${DOMAIN}/health"
echo ""
echo "📋 SSL Certificate:"
echo "   $(openssl x509 -enddate -noout -in /etc/letsencrypt/live/${DOMAIN}/fullchain.pem 2>/dev/null || echo 'Check /etc/letsencrypt/live/')"
echo ""
echo "🔄 Auto-renewal: Enabled (certbot renew runs twice daily)"
echo ""
echo "📱 Next step: Update your Flutter app's API base URL to:"
echo "   https://${DOMAIN}"
echo ""
echo "Useful commands:"
echo "  Test cert renewal:  certbot renew --dry-run"
echo "  Check cert expiry:  openssl x509 -enddate -noout -in /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
echo "  Nginx logs:         docker logs -f apexrun_nginx"
echo "  Reload nginx:       docker exec apexrun_nginx nginx -s reload"
