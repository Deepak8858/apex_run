# ApexRun Backend — Digital Ocean Deployment Guide

This guide walks you through deploying the ApexRun Go backend on Digital Ocean using Docker.

## 🚀 Quick Deployment (Recommended)

### Option 1: Digital Ocean App Platform (Easiest)

Digital Ocean App Platform will automatically build and deploy your Docker container.

1. **Push your code to GitHub**
   ```bash
   git add .
   git commit -m "Production deployment"
   git push origin main
   ```

2. **Create App on Digital Ocean**
   - Go to [Digital Ocean App Platform](https://cloud.digitalocean.com/apps)
   - Click **Create App** → **GitHub** → Select your `apex_run` repository
   - Select `backend/` as the source directory
   - App Platform will auto-detect the Dockerfile

3. **Configure Environment Variables**
   In the App Platform dashboard, add these environment variables:
   ```
   SUPABASE_URL=https://<YOUR_PROJECT_REF>.supabase.co
   SUPABASE_ANON_KEY=<REPLACE_WITH_ROTATED_ANON_KEY>
   SUPABASE_SERVICE_KEY=<your-service-role-key>
   SUPABASE_JWT_SECRET=<your-jwt-secret>
   DATABASE_URL=postgresql://postgres:<password>@db.<YOUR_PROJECT_REF>.supabase.co:5432/postgres
   REDIS_URL=<REDIS_HOST>:6379
   REDIS_PASSWORD=<REPLACE_WITH_ROTATED_REDIS_PASSWORD>
   REDIS_DB=0
   PORT=8080
   GIN_MODE=release
   ALLOWED_ORIGINS=https://apexrun.app,https://*.apexrun.app
   LOG_LEVEL=info
   LOG_FORMAT=json
   ```

4. **Configure Resources**
   - Instance Size: **Basic ($5/month)** for development, **Pro ($12/month)** for production
   - HTTP Routes: Port 8080
   - Health Check: `/health`

5. **Deploy**
   - Click **Create Resources**
   - App Platform will build the Docker image and deploy it
   - Your API will be live at `https://your-app-name.ondigitalocean.app`

6. **Update Flutter App**
   Update `lib/core/config/env.dart`:
   ```dart
   static const String backendApiUrl = String.fromEnvironment(
     'BACKEND_API_URL',
     defaultValue: 'https://your-app-name.ondigitalocean.app',
   );
   ```

---

### Option 2: Digital Ocean Droplet (More Control)

Deploy on a virtual machine with full control.

#### 1. Create a Droplet

```bash
# Use doctl CLI (install from https://docs.digitalocean.com/reference/doctl/)
doctl compute droplet create apexrun-backend \
  --image docker-20-04 \
  --size s-1vcpu-1gb \
  --region nyc3 \
  --ssh-keys <your-ssh-key-id>
```

Or create via [Digital Ocean Console](https://cloud.digitalocean.com/droplets):
- **Image**: Docker on Ubuntu 22.04
- **Size**: Basic - $6/month (1 vCPU, 1GB RAM)
- **Region**: Choose closest to your users
- **SSH Key**: Add your public key

#### 2. SSH into Droplet

```bash
ssh root@your-droplet-ip
```

#### 3. Clone Repository

```bash
git clone https://github.com/your-username/apex_run.git
cd apex_run/backend
```

#### 4. Create Production Environment File

```bash
nano .env
```

Paste this configuration (update with your actual credentials):

```env
SUPABASE_URL=https://<YOUR_PROJECT_REF>.supabase.co
SUPABASE_ANON_KEY=<REPLACE_WITH_ROTATED_ANON_KEY>
SUPABASE_SERVICE_KEY=<YOUR_SERVICE_ROLE_KEY_HERE>
SUPABASE_JWT_SECRET=<YOUR_JWT_SECRET_FROM_SUPABASE_SETTINGS>
DATABASE_URL=postgresql://postgres:<PASSWORD>@db.<YOUR_PROJECT_REF>.supabase.co:5432/postgres
REDIS_URL=<REDIS_HOST>:6379
REDIS_PASSWORD=<REPLACE_WITH_ROTATED_REDIS_PASSWORD>
REDIS_DB=0
PORT=8080
GIN_MODE=release
ALLOWED_ORIGINS=https://apexrun.app,https://*.apexrun.app
LOG_LEVEL=info
LOG_FORMAT=json
SEGMENT_MATCH_BUFFER_METERS=20
MAX_GPS_POINTS_PER_ACTIVITY=10000
```

Save: `Ctrl+O`, `Enter`, `Ctrl+X`

#### 5. Deploy with Docker Compose

Create production docker-compose:

```bash
nano docker-compose.prod.yml
```

Paste:

```yaml
version: '3.8'

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: apexrun_backend
    restart: unless-stopped
    ports:
      - "8080:8080"
    env_file:
      - .env
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Optional: Nginx reverse proxy with SSL
  nginx:
    image: nginx:alpine
    container_name: apexrun_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - backend
```

#### 6. Start the Backend

```bash
docker-compose -f docker-compose.prod.yml up -d --build
```

#### 7. Verify Deployment

```bash
# Check logs
docker-compose -f docker-compose.prod.yml logs -f backend

# Test health endpoint
curl http://localhost:8080/health

# Should return: {"status":"ok","database":"connected","redis":"connected"}
```

#### 8. Set Up Firewall

```bash
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 8080/tcp  # Backend (or only allow from nginx)
ufw enable
```

#### 9. SSL Certificate (Optional but Recommended)

```bash
# Install certbot
apt update
apt install certbot

# Get SSL certificate
certbot certonly --standalone -d api.apexrun.app

# Certificate will be saved to /etc/letsencrypt/live/api.apexrun.app/
```

#### 10. Update Flutter App

```dart
static const String backendApiUrl = String.fromEnvironment(
  'BACKEND_API_URL',
  defaultValue: 'https://api.apexrun.app',
);
```

---

## 🔄 Continuous Deployment

### Auto-Deploy on Git Push

1. **Create Deploy Script** (`deploy.sh`):

```bash
#!/bin/bash
cd /root/apex_run/backend
git pull origin main
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d --build
docker-compose -f docker-compose.prod.yml logs -f --tail=50
```

2. **Set Up GitHub Webhook**:
   - GitHub Repo → Settings → Webhooks → Add webhook
   - Payload URL: `http://your-droplet-ip:9000/hooks/deploy`
   - Use [webhook](https://github.com/adnanh/webhook) to trigger deploy script

---

## 📊 Monitoring & Logs

```bash
# View logs
docker-compose -f docker-compose.prod.yml logs -f backend

# Check resource usage
docker stats

# Restart backend
docker-compose -f docker-compose.prod.yml restart backend

# Stop all services
docker-compose -f docker-compose.prod.yml down
```

---

## 🛠️ Debugging

### Backend container won't start
```bash
docker-compose -f docker-compose.prod.yml logs backend
```

### Check health endpoint
```bash
curl http://localhost:8080/health
```

### Database connection issues
```bash
# Test DB connection from droplet
psql "postgresql://postgres:<PASSWORD>@db.<YOUR_PROJECT_REF>.supabase.co:5432/postgres"
```

### Redis connection issues
```bash
# Test Redis connection
redis-cli -h "$REDIS_HOST" -p 6379 -a "$REDIS_PASSWORD" ping  # read from env
```

---

## 💰 Cost Estimate

### App Platform (Recommended)
- **Basic**: $5/month (512MB RAM, 1 vCPU)
- **Pro**: $12/month (1GB RAM, 1 vCPU)
- Includes automatic scaling, zero-downtime deployments, CDN

### Droplet
- **Basic**: $6/month (1GB RAM, 1 vCPU, 25GB SSD)
- **Standard**: $12/month (2GB RAM, 1 vCPU, 50GB SSD)
- You manage everything (more control, more responsibility)

---

## 🚨 Security Checklist

- [x] Use environment variables for secrets (never commit `.env`)
- [x] Enable HTTPS/SSL certificate
- [x] Configure firewall (UFW)
- [x] Set `GIN_MODE=release` in production
- [x] Use Supabase service role key (not anon key) for backend
- [x] Restrict CORS origins to your domain
- [x] Enable rate limiting
- [x] Set up monitoring/alerts (Digital Ocean Monitoring or Datadog)
- [x] Regular backups (Supabase handles DB backups)
- [x] Keep Docker images updated

---

## 📚 Additional Resources

- [Digital Ocean App Platform Docs](https://docs.digitalocean.com/products/app-platform/)
- [Docker Compose Production Guide](https://docs.docker.com/compose/production/)
- [Supabase Production Checklist](https://supabase.com/docs/guides/platform/going-into-prod)

---

**Your backend is now production-ready! 🎉**

Public API: `https://your-app-name.ondigitalocean.app`  
Health Check: `https://your-app-name.ondigitalocean.app/health`
