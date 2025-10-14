#!/bin/bash
set -e

echo "========================================"
echo "DEPLOYING CLAIMS BACKEND"
echo "========================================"

# Check if .env file exists
if [ ! -f ".env" ]; then
  echo "ERROR: .env file not found!"
  echo "Please copy .env.example to .env and configure it:"
  echo "  cp .env.example .env"
  echo "  # Edit .env with your settings"
  exit 1
fi

# Check if AME keystore exists
if [ ! -f "config/claims.p12" ]; then
  echo "WARNING: AME keystore not found!"
  echo "Please generate the keystore first:"
  echo "  ./docker/scripts/generate-ame-keystore.sh"
  echo ""
  read -p "Continue without AME keystore? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

echo "Stopping existing containers..."
docker-compose down

echo ""
echo "Building images..."
docker-compose build

echo ""
echo "Starting services..."
docker-compose up -d

echo ""
echo "Waiting for services to be healthy..."
sleep 10

echo ""
echo "Service status:"
docker-compose ps

echo ""
echo "Application logs (last 50 lines):"
docker-compose logs --tail=50 app

echo ""
echo "========================================"
echo "DEPLOYMENT COMPLETE"
echo "========================================"
echo "✓ All services started successfully"
echo "✓ Application available at: http://localhost:8080"
echo "✓ Database accessible at: localhost:5432"
echo "✓ Health check: curl http://localhost:8080/actuator/health"
echo ""
echo "Next steps:"
echo "1. Check application health: curl http://localhost:8080/actuator/health"
echo "2. View logs: docker-compose logs -f app"
echo "3. Access database: ./docker/scripts/db-shell.sh"
echo "========================================"
