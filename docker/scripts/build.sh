#!/bin/bash
set -e

echo "========================================"
echo "BUILDING DOCKER IMAGES"
echo "========================================"

echo "Building Docker images with no cache..."
docker-compose build --no-cache

echo ""
echo "Build complete! Docker images:"
docker images | grep claims || echo "No claims images found"

echo ""
echo "========================================"
echo "BUILD SUMMARY"
echo "========================================"
echo "✓ Main application image built"
echo "✓ Database initialization image built"
echo "✓ All images ready for deployment"
echo "========================================"
