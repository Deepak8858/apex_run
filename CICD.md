# ApexRun CI/CD Pipeline Documentation

Complete guide for Continuous Integration and Continuous Deployment setup for the ApexRun application.

---

## 📋 Table of Contents

- [Overview](#overview)
- [CI/CD Architecture](#cicd-architecture)
- [GitHub Actions Workflows](#github-actions-workflows)
- [DigitalOcean App Platform Deployment](#digitalocean-app-platform-deployment)
- [Manual Deployment Options](#manual-deployment-options)
- [Environment Variables & Secrets](#environment-variables--secrets)
- [Monitoring & Debugging](#monitoring--debugging)
- [Rollback Procedures](#rollback-procedures)
- [Best Practices](#best-practices)

---

## 🎯 Overview

ApexRun uses a multi-stage CI/CD pipeline that:

1. **Validates code quality** through automated testing and linting
2. **Builds artifacts** for Flutter mobile app and Go backend
3. **Deploys automatically** to DigitalOcean infrastructure
4. **Monitors health** and provides rollback capabilities

### Supported Platforms

- **Backend**: Go API deployed to DigitalOcean App Platform
- **Frontend**: Flutter mobile app (Android/iOS)
- **Database**: Supabase PostgreSQL (managed)
- **Cache**: Redis (self-hosted)

---

## 🏗️ CI/CD Architecture

```
┌─────────────────┐
│   Developer     │
│   Git Push      │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────┐
│      GitHub Actions Triggers        │
│  • Push to main/develop             │
│  • Pull Request to main             │
│  • Manual workflow dispatch         │
└────────┬────────────────────────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌─────────┐  ┌──────────────────┐
│   CI    │  │  Deploy Backend  │
│ Workflow│  │    Workflow      │
└────┬────┘  └────────┬─────────┘
     │                │
     │                ▼
     │        ┌───────────────────┐
     │        │ DigitalOcean App  │
     │        │    Platform       │
     │        └────────┬──────────┘
     │                 │
     │                 ▼
     │        ┌───────────────────┐
     │        │  Live Production  │
     │        │   apex-backend    │
     │        └───────────────────┘
     │
     ▼
┌─────────────────────┐
│  Test Results &     │
│  Build Artifacts    │
└─────────────────────┘
```

---

## ⚙️ GitHub Actions Workflows

### 1. CI Workflow (`.github/workflows/ci.yml`)

**Trigger**: Push to `main`/`develop` or PR to `main`

#### Jobs

##### a) Flutter Analyze
- **Purpose**: Static code analysis and formatting checks
- **Steps**:
  ```yaml
  - Checkout code
  - Setup Flutter 3.24.0
  - Get dependencies
  - Run code generation (build_runner)
  - Analyze code (flutter analyze)
  - Check formatting (dart format)
  ```
- **Runtime**: ~2-3 minutes

##### b) Flutter Test
- **Purpose**: Run unit, widget, and integration tests
- **Dependencies**: Requires `flutter-analyze` to pass
- **Steps**:
  ```yaml
  - Run unit tests with coverage
  - Run widget tests with coverage
  - Run integration tests with coverage
  - Upload coverage reports
  ```
- **Runtime**: ~5-8 minutes

##### c) Flutter Build Android
- **Purpose**: Build production APK
- **Trigger**: Only on push to `main` (not PRs)
- **Steps**:
  ```yaml
  - Setup Java 17
  - Setup Flutter
  - Generate code
  - Build Android APK (release mode)
  - Upload APK artifact
  ```
- **Output**: `app-release.apk` (uploaded as GitHub artifact)
- **Runtime**: ~10-15 minutes

##### d) Go Backend CI
- **Purpose**: Test and validate Go backend code
- **Steps**:
  ```yaml
  - Setup Go 1.22
  - Install dependencies (go mod download)
  - Run tests (go test ./...)
  - Build binary
  - Upload coverage
  ```
- **Runtime**: ~3-5 minutes

---

### 2. Deploy Backend Workflow (`.github/workflows/deploy-backend.yml`)

**Trigger**: 
- Push to `main` with changes in `backend/` directory
- Manual trigger via `workflow_dispatch`

#### Deployment Steps

```yaml
1. Checkout code
2. Setup SSH with droplet private key
3. Add Digital Ocean to known_hosts
4. SSH into droplet and execute:
   - Pull latest code (git pull origin main)
   - Stop containers (docker-compose down)
   - Rebuild images (docker-compose build)
   - Start containers (docker-compose up -d)
   - Wait for health check (/health endpoint)
   - Verify deployment or rollback
```

#### Health Check Process

```bash
# 30-second polling with 2-second intervals
for i in {1..30}; do
  if curl -f http://localhost:8080/health; then
    echo "✅ Deployment successful!"
    exit 0
  fi
  sleep 2
done
echo "❌ Deployment failed - rolling back"
```

#### Required GitHub Secrets

| Secret | Description | Example |
|--------|-------------|---------|
| `DO_SSH_PRIVATE_KEY` | SSH private key for droplet access | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `DO_DROPLET_IP` | Droplet IP address | `165.227.123.45` |

---

## 🚀 DigitalOcean App Platform Deployment

### Automatic Deployment (Recommended)

ApexRun backend is deployed to DigitalOcean App Platform with auto-deploy enabled.

#### App Configuration

**App ID**: `61e5e2ce-c9d7-4c03-9326-7bbfac8889f9`  
**Name**: `apex-backend`  
**Region**: Bangalore (blr)  
**Tier**: Professional  

#### Deployment Spec

```yaml
name: apex-backend
region: blr
services:
  - name: apex-run-backend
    github:
      repo: Deepak8858/apex_run
      branch: main
      deploy_on_push: true    # Auto-deploy on git push
    dockerfile_path: backend/Dockerfile
    source_dir: backend
    http_port: 8080
    instance_size_slug: apps-s-1vcpu-1gb
    instance_count: 1
    health_check:
      http_path: /health
      initial_delay_seconds: 60
      period_seconds: 30
      timeout_seconds: 10
      failure_threshold: 5
```

#### Environment Variables (21 total)

All environment variables are configured in the App Platform dashboard:

**Supabase Configuration**:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_KEY` (SECRET)
- `SUPABASE_JWT_SECRET` (SECRET)

**Database Configuration**:
- `DATABASE_URL` (SECRET) - includes `?sslmode=require`
- `DB_MAX_OPEN_CONNS=25`
- `DB_MAX_IDLE_CONNS=10`
- `DB_CONN_MAX_LIFETIME_MINUTES=30`

**Redis Configuration**:
- `REDIS_URL=134.199.187.2:6379`
- `REDIS_PASSWORD` (SECRET)
- `REDIS_DB=0`
- `REDIS_POOL_SIZE=10`

**Server Configuration**:
- `PORT=8080`
- `GIN_MODE=release`
- `ALLOWED_ORIGINS=https://apexrun.app,https://www.apexrun.app,https://api.apexrun.app`
- `RATE_LIMIT_REQUESTS_PER_MINUTE=60`

**GPS & Segments**:
- `SEGMENT_MATCH_BUFFER_METERS=20`
- `MAX_GPS_POINTS_PER_ACTIVITY=10000`

**Logging**:
- `LOG_LEVEL=info`
- `LOG_FORMAT=json`

**Security**:
- `ENABLE_MOCK_DATA=false`
- `ENABLE_DEBUG_LOGGING=false`

#### Deployment Triggers

1. **Git Push**: Any push to `main` branch triggers auto-deployment
2. **Manual**: Via DigitalOcean dashboard or MCP API
3. **App Spec Update**: Changes to configuration trigger redeployment

#### Deployment Pipeline Stages

```
QUEUED → BUILDING → DEPLOYING → ACTIVE
   ↓         ↓          ↓          ↓
  30s     3-5min    1-2min     Running

Failure Recovery:
ERROR → Logs Available → Previous Version Remains Active
```

---

## 🔧 Manual Deployment Options

### Option 1: Deploy Script (Droplet Only)

```bash
# SSH into droplet
ssh root@YOUR_DROPLET_IP

# Run deployment script
cd /root/apex_run
./deploy.sh production
```

**What it does**:
1. Pulls latest code from GitHub
2. Validates `.env` file exists
3. Stops running containers
4. Rebuilds Docker images
5. Starts containers
6. Waits for health check
7. Shows logs on failure

### Option 2: Docker Compose (Droplet)

```bash
cd /root/apex_run

# Stop containers
docker-compose -f docker-compose.prod.yml down

# Rebuild and start
docker-compose -f docker-compose.prod.yml up -d --build

# View logs
docker-compose -f docker-compose.prod.yml logs -f backend
```

### Option 3: DigitalOcean MCP Server

**Using Claude Code with MCP**:

```typescript
// List apps
mcp_digitalocean-_apps-list()

// Get deployment status
mcp_digitalocean-_apps-get-deployment-status({
  AppID: "61e5e2ce-c9d7-4c03-9326-7bbfac8889f9"
})

// Update app configuration
mcp_digitalocean-_apps-update({
  app_id: "61e5e2ce-c9d7-4c03-9326-7bbfac8889f9",
  request: { spec: {...} }
})
```

### Option 4: DigitalOcean CLI (doctl)

```bash
# Install doctl
brew install doctl  # macOS
# or
snap install doctl  # Linux

# Authenticate
doctl auth init

# List apps
doctl apps list

# Trigger deployment
doctl apps create-deployment <APP_ID>

# View logs
doctl apps logs <APP_ID> --type=BUILD
doctl apps logs <APP_ID> --type=DEPLOY
doctl apps logs <APP_ID> --type=RUN
```

---

## 🔐 Environment Variables & Secrets

### Setting Up GitHub Secrets

1. **Navigate to GitHub**:
   ```
   Repository → Settings → Secrets and variables → Actions
   ```

2. **Add Required Secrets**:

   **DO_SSH_PRIVATE_KEY**:
   ```bash
   # Generate SSH key pair
   ssh-keygen -t ed25519 -C "github-actions@apexrun"
   
   # Copy private key (add to GitHub)
   cat ~/.ssh/id_ed25519
   
   # Copy public key (add to droplet)
   cat ~/.ssh/id_ed25519.pub
   ```

   **DO_DROPLET_IP**:
   ```
   Value: Your droplet's IP address (e.g., 165.227.123.45)
   ```

### Setting Up DigitalOcean Secrets

Secrets are managed directly in the App Platform dashboard or via MCP:

```typescript
// Update with secrets
{
  "key": "DATABASE_URL",
  "scope": "RUN_AND_BUILD_TIME",
  "type": "SECRET",
  "value": "postgresql://..."
}
```

**Important**: Secrets are encrypted by DigitalOcean and displayed as `EV[1:...]`

### Environment File Structure

**Development** (`.env`):
```env
SUPABASE_URL=http://127.0.0.1:54321
DATABASE_URL=postgresql://postgres:postgres@localhost:54322/postgres
REDIS_URL=localhost:6379
GIN_MODE=debug
LOG_LEVEL=debug
```

**Production** (`.env.production`):
```env
SUPABASE_URL=https://voddddmmiarnbvwmgzgo.supabase.co
DATABASE_URL=postgresql://...?sslmode=require
REDIS_URL=134.199.187.2:6379
GIN_MODE=release
LOG_LEVEL=info
LOG_FORMAT=json
```

---

## 📊 Monitoring & Debugging

### Health Check Endpoint

```bash
# Check if backend is healthy
curl https://apex-backend-xyz.ondigitalocean.app/health

# Expected response:
{
  "status": "ok",
  "database": "connected",
  "redis": "connected",
  "timestamp": "2026-02-11T10:30:00Z"
}
```

### View Deployment Logs

**DigitalOcean Dashboard**:
```
Apps → apex-backend → Runtime Logs
```

**Terminal (doctl)**:
```bash
# Build logs
doctl apps logs 61e5e2ce-c9d7-4c03-9326-7bbfac8889f9 --type=BUILD --follow

# Runtime logs
doctl apps logs 61e5e2ce-c9d7-4c03-9326-7bbfac8889f9 --type=RUN --follow
```

**Docker (Droplet)**:
```bash
docker-compose -f docker-compose.prod.yml logs -f backend
```

### Common Issues & Solutions

#### 1. Build Fails: "go.mod not found"

**Cause**: Incorrect `source_dir` in app spec  
**Fix**: Ensure `source_dir: backend` is set

#### 2. Container Crashes: "docker: command not found"

**Cause**: `run_command` trying to run Docker-in-Docker  
**Fix**: Remove `run_command` field from app spec (use Dockerfile ENTRYPOINT)

#### 3. Database Connection Failed

**Cause**: Missing `?sslmode=require` in DATABASE_URL  
**Fix**: Update DATABASE_URL:
```
postgresql://user:pass@host:port/db?sslmode=require
```

#### 4. Health Check Timeout

**Cause**: App takes too long to start  
**Fix**: Increase `initial_delay_seconds` to 60+ in health check config

#### 5. Deployment Stuck in "Building"

**Cause**: DigitalOcean build queue delay  
**Fix**: Wait 5-10 minutes or cancel and retry

---

## 🔄 Rollback Procedures

### DigitalOcean App Platform Rollback

**Option 1: Via Dashboard**:
1. Go to `Apps → apex-backend → Deployments`
2. Find previous successful deployment
3. Click **Rollback to this deployment**

**Option 2: Via MCP**:
```typescript
// List deployments
mcp_digitalocean-_apps-list-deployments({
  AppID: "61e5e2ce-c9d7-4c03-9326-7bbfac8889f9"
})

// Rollback to specific deployment
mcp_digitalocean-_apps-rollback({
  AppID: "61e5e2ce-c9d7-4c03-9326-7bbfac8889f9",
  DeploymentID: "previous-deployment-id"
})
```

### Docker Droplet Rollback

```bash
# SSH into droplet
ssh root@YOUR_DROPLET_IP

# View git history
cd /root/apex_run
git log --oneline -10

# Rollback to previous commit
git reset --hard <commit-hash>

# Redeploy
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d --build
```

### Emergency Rollback (Database Issue)

If database migration causes issues:

```bash
# SSH into droplet
ssh root@YOUR_DROPLET_IP

# Connect to database
psql "$DATABASE_URL"

# Rollback migration
-- Check migration history
SELECT * FROM schema_migrations ORDER BY version DESC LIMIT 10;

-- Manually rollback
DELETE FROM schema_migrations WHERE version = 'YYYYMMDDHHMMSS';
-- Run rollback SQL
```

---

## ✅ Best Practices

### 1. Code Quality Gates

```yaml
# Enforce in ci.yml
- Flutter analyze with no errors
- All tests passing (100% critical paths)
- Code coverage > 80% (recommended)
- Dart formatting enforced
```

### 2. Deployment Strategy

**Blue-Green Deployment** (App Platform):
- DigitalOcean automatically keeps previous version running
- New version tested via health checks
- Switch happens only if healthy
- Instant rollback available

**Canary Deployment** (Manual):
```bash
# Deploy to staging first
git push origin develop

# Test thoroughly
curl https://staging.apexrun.app/health

# Merge to main for production
git checkout main
git merge develop
git push origin main
```

### 3. Secret Rotation

Rotate secrets quarterly:

```bash
# Update secrets in DigitalOcean App Platform
1. Generate new Supabase service key
2. Update DATABASE_URL password
3. Rotate Redis password
4. Redeploy app (secrets applied on restart)
```

### 4. Monitoring Alerts

**Set up in DigitalOcean**:
- `DEPLOYMENT_FAILED` → Email notification
- `DOMAIN_FAILED` → Email notification
- CPU > 80% → Scale up instance
- Memory > 85% → Scale up instance

### 5. Database Migrations

**Always use migration files**:
```bash
# Create new migration
cd backend/migrations
touch 20260211_add_feature.sql

# Test locally
psql "$DATABASE_URL_LOCAL" < 20260211_add_feature.sql

# Deploy via git push (auto-applied)
git add migrations/
git commit -m "feat: add new feature migration"
git push origin main
```

### 6. Version Tagging

```bash
# Tag releases
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Reference in deployment
# Update cmd/api/main.go
const version = "1.0.0"
```

---

## 📚 Additional Resources

- [DigitalOcean App Platform Docs](https://docs.digitalocean.com/products/app-platform/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Compose Production Guide](https://docs.docker.com/compose/production/)
- [Supabase Production Checklist](https://supabase.com/docs/guides/platform/going-into-prod)
- [Go Backend Deployment Guide](./DEPLOY_DIGITALOCEAN.md)

---

## 🆘 Support & Troubleshooting

**Monitor Live Deployment**:
- Dashboard: https://cloud.digitalocean.com/apps/61e5e2ce-c9d7-4c03-9326-7bbfac8889f9
- Health Check: https://apex-backend-xyz.ondigitalocean.app/health

**Common Commands**:
```bash
# Check deployment status
doctl apps list

# View build logs
doctl apps logs <APP_ID> --type=BUILD

# View runtime logs
doctl apps logs <APP_ID> --type=RUN --follow

# Restart app
doctl apps create-deployment <APP_ID>
```

**Emergency Contacts**:
- GitHub Actions: Check workflow run logs
- DigitalOcean: https://status.digitalocean.com
- Supabase: https://status.supabase.com

---

**Last Updated**: February 11, 2026  
**Maintained By**: ApexRun DevOps Team
