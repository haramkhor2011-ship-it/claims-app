#!/bin/bash

SERVICE=${1:-}

echo "========================================"
echo "VIEWING DOCKER LOGS"
echo "========================================"

if [ -z "$SERVICE" ]; then
  echo "Showing logs for all services..."
  echo "Usage: $0 [service_name] to view specific service logs"
  echo "Available services: postgres, db-init, app"
  echo ""
  docker-compose logs -f
else
  echo "Showing logs for service: $SERVICE"
  echo ""
  docker-compose logs -f "$SERVICE"
fi
