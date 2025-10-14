#!/bin/bash

echo "========================================"
echo "CLEANING DOCKER ENVIRONMENT"
echo "========================================"
echo "WARNING: This will remove all containers and images!"
echo "This will also remove the PostgreSQL data volume!"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Clean cancelled."
  exit 0
fi

echo ""
echo "Stopping containers..."
docker-compose down

echo ""
echo "Removing containers..."
docker-compose rm -f

echo ""
echo "Removing images..."
docker rmi $(docker images -q 'claims*') 2>/dev/null || echo "No claims images to remove"

echo ""
echo "Removing volumes..."
docker volume rm claims-backend-full_postgres-data 2>/dev/null || echo "No postgres volume to remove"

echo ""
echo "Cleaning build artifacts..."
rm -rf target/ 2>/dev/null || echo "No target directory to remove"

echo ""
echo "Cleaning Docker system..."
docker system prune -f

echo ""
echo "========================================"
echo "CLEAN COMPLETE"
echo "========================================"
echo "✓ All containers removed"
echo "✓ All images removed"
echo "✓ All volumes removed"
echo "✓ Build artifacts cleaned"
echo "✓ Docker system pruned"
echo ""
echo "To redeploy:"
echo "1. ./docker/scripts/generate-ame-keystore.sh"
echo "2. ./docker/scripts/deploy.sh"
echo "========================================"
