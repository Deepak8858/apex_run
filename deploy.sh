#!/bin/bash
set -e

# ApexRun Backend Deployment Script for Digital Ocean
# Usage: ./deploy.sh [production|staging]

ENVIRONMENT=${1:-production}
PROJECT_DIR="/root/apex_run"
COMPOSE_FILE="docker-compose.prod.yml"

echo "🚀 Starting ApexRun Backend Deployment (${ENVIRONMENT})"
echo "=================================================="

# Navigate to project directory
cd ${PROJECT_DIR}

# Pull latest code
echo "📦 Pulling latest code from GitHub..."
git fetch origin
git reset --hard origin/main

# Check if .env file exists
if [ ! -f "./backend/.env" ]; then
    echo "❌ ERROR: backend/.env file not found!"
    echo "Please create it from backend/.env.example"
    exit 1
fi

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f ${COMPOSE_FILE} down

# Remove old images to force rebuild
echo "🗑️  Removing old images..."
docker-compose -f ${COMPOSE_FILE} rm -f backend

# Build and start services
echo "🔨 Building and starting services..."
docker-compose -f ${COMPOSE_FILE} up -d --build

# Wait for backend to be healthy
echo "⏳ Waiting for backend to be healthy..."
for i in {1..30}; do
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        echo "✅ Backend is healthy!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Backend health check failed after 30 attempts"
        docker-compose -f ${COMPOSE_FILE} logs backend
        exit 1
    fi
    echo "   Attempt $i/30..."
    sleep 2
done

# Show logs
echo ""
echo "📋 Recent logs:"
docker-compose -f ${COMPOSE_FILE} logs --tail=20 backend

echo ""
echo "✨ Deployment complete!"
echo "=================================================="
echo "Backend API: http://localhost:8080"
echo "Health Check: http://localhost:8080/health"
echo ""
echo "View logs: docker-compose -f ${COMPOSE_FILE} logs -f backend"
echo "Stop services: docker-compose -f ${COMPOSE_FILE} down"
