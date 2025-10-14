#!/bin/bash
set -e

echo "========================================"
echo "CLAIMS DATABASE INITIALIZATION"
echo "========================================"

# Wait for postgres to be ready
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h postgres -U claims_user; do
  echo "PostgreSQL is not ready yet, waiting..."
  sleep 2
done

echo "PostgreSQL is ready!"

# Check if database is already initialized
echo "Checking if database is already initialized..."
INITIALIZED=$(psql -h postgres -U claims_user -d claims -tAc "SELECT EXISTS(SELECT 1 FROM claims.integration_toggle WHERE code='db.initialized' AND enabled=true);" 2>/dev/null || echo "false")

if [ "$INITIALIZED" = "t" ]; then
  echo "Database is already initialized, skipping initialization..."
  echo "========================================"
  echo "INITIALIZATION SKIPPED - ALREADY COMPLETE"
  echo "========================================"
  exit 0
fi

echo "Database not initialized, starting initialization process..."

# Run initialization scripts in order
echo "Running database initialization scripts..."

for sql_file in /docker-entrypoint-initdb.d/*.sql; do
  if [ -f "$sql_file" ]; then
    echo "Executing: $(basename "$sql_file")"
    psql -h postgres -U claims_user -d claims -f "$sql_file"
    if [ $? -eq 0 ]; then
      echo "✓ Successfully executed: $(basename "$sql_file")"
    else
      echo "✗ Failed to execute: $(basename "$sql_file")"
      exit 1
    fi
  fi
done

echo "========================================"
echo "DATABASE INITIALIZATION COMPLETE"
echo "========================================"
echo "All initialization scripts executed successfully!"
echo "Database is now ready for use."
echo "========================================"
