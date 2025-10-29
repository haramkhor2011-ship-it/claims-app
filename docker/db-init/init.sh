#!/bin/bash
set -e

# Export password for psql commands
export PGPASSWORD="${POSTGRES_PASSWORD:-securepass}"

echo "========================================"
echo "CLAIMS DATABASE INITIALIZATION"
echo "========================================"

# Wait for postgres to be ready
echo "Waiting for PostgreSQL to be ready..."
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_USER="${POSTGRES_USER:-claims_user}"
until pg_isready -h "$POSTGRES_HOST" -U "$POSTGRES_USER"; do
  echo "PostgreSQL is not ready yet, waiting..."
  sleep 2
done

echo "PostgreSQL is ready!"

# Check if database is already initialized
echo "Checking if database is already initialized..."
POSTGRES_DB="${POSTGRES_DB:-claims}"
INITIALIZED=$(psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT EXISTS(SELECT 1 FROM claims.integration_toggle WHERE code='db.initialized' AND enabled=true);" 2>/dev/null || echo "false")

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

for sql_file in /scripts/*.sql; do
  if [ -f "$sql_file" ] && [[ ! "$sql_file" =~ \.skip$ ]]; then
    echo "Executing: $(basename "$sql_file")"
    psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$sql_file"
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

# Exit successfully to complete the init container
exit 0
