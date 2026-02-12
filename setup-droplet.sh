#!/bin/bash
set -e

# ApexRun Backend - Digital Ocean Droplet Initial Setup
# Run this script on a fresh Ubuntu 22.04 droplet to set up everything

echo "🚀 ApexRun Backend - Digital Ocean Setup"
echo "========================================"
echo ""

# Update system
echo "📦 Updating system packages..."
apt-get update
apt-get upgrade -y

# Install Docker
echo "🐳 Installing Docker..."
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable IPv6 in Docker daemon (required for Supabase direct connection)
echo "🌐 Enabling IPv6 in Docker..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:db8:1::/64",
  "experimental": true,
  "ip6tables": true
}
EOF
systemctl restart docker

# Install Docker Compose standalone
echo "📝 Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install other utilities
echo "🛠️ Installing utilities..."
apt-get install -y git curl wget ufw redis-tools postgresql-client

# Configure firewall
echo "🔒 Configuring firewall..."
ufw --force enable
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS
ufw allow 8080/tcp # Backend API
ufw status

# Clone repository
echo "📥 Cloning ApexRun repository..."
cd /root
if [ -d "apex_run" ]; then
    echo "Repository already exists, pulling latest..."
    cd apex_run
    git pull origin main
else
    git clone https://github.com/Deepak8858/apex_run.git
    cd apex_run
fi

# Create .env file
echo ""
echo "📝 Creating environment configuration..."
if [ ! -f "./backend/.env" ]; then
    # Copies the production environment configuration file to the default environment file
    # for the backend application. This assumes the backend directory exists in the current
    # working directory and is typically run during deployment/setup on Ubuntu or similar Unix-like systems.
    # Note: Ensure ./backend/.env.production exists before running this command.
    cp ./backend/.env.production ./backend/.env
    echo "⚠️  IMPORTANT: Edit backend/.env with your actual credentials:"
    echo "   nano backend/.env"
    echo ""
    echo "Required values:"
    echo "  - SUPABASE_SERVICE_KEY (from Supabase dashboard)"
    echo "  - SUPABASE_JWT_SECRET (from Supabase dashboard)"
    echo "  - DATABASE_URL (PostgreSQL connection string)"
    echo ""
    read -p "Press Enter after you've updated the .env file..."
else
    echo "✅ .env file already exists"
fi

# Build and start services
echo "🔨 Building and starting services..."
docker-compose -f docker-compose.prod.yml up -d --build

# Wait for backend to be ready
echo "⏳ Waiting for backend to be ready..."
for i in {1..30}; do
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        echo "✅ Backend is healthy!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Health check failed. Checking logs..."
        docker-compose -f docker-compose.prod.yml logs backend
        exit 1
    fi
    echo "   Attempt $i/30..."
    sleep 2
done

# Get droplet IP
DROPLET_IP=$(curl -s http://ifconfig.me)

echo ""
echo "✨ Setup Complete!"
echo "========================================"
echo "Backend API: http://$DROPLET_IP:8080"
echo "Health Check: http://$DROPLET_IP:8080/health"
echo ""
echo "Next steps:"
echo "1. Set up a domain name and point it to: $DROPLET_IP"
echo "2. Get SSL certificate: certbot certonly --standalone -d api.apexrun.app"
echo "3. Enable Nginx reverse proxy in docker-compose.prod.yml"
echo "4. Update Flutter app with: https://api.apexrun.app"
echo ""
echo "Useful commands:"
echo "  View logs: docker-compose -f docker-compose.prod.yml logs -f backend"
echo "  Restart: docker-compose -f docker-compose.prod.yml restart backend"
echo "  Deploy updates: ./deploy.sh"
echo ""
echo "Make deploy.sh executable: chmod +x deploy.sh"
