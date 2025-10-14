#!/bin/bash

echo "========================================"
echo "POSTGRESQL DATABASE SHELL"
echo "========================================"
echo "Connecting to claims database..."
echo "Database: claims"
echo "User: claims_user"
echo "Host: localhost:5432"
echo ""
echo "Useful commands:"
echo "  \\l          - List databases"
echo "  \\dn         - List schemas"
echo "  \\dt claims.* - List claims tables"
echo "  \\dm claims.* - List materialized views"
echo "  \\q          - Quit"
echo "========================================"
echo ""

docker exec -it claims-postgres psql -U claims_user -d claims
