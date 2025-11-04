# PostgreSQL Container - Query Guide

## Quick Access Commands

### Method 1: Direct psql Access (Recommended)
```powershell
# Connect directly to PostgreSQL
docker exec -it claims-postgres psql -U claims_user -d claims

# Once connected, you can run SQL queries:
SELECT COUNT(*) FROM claims.payer;
\q  # Exit psql
```

### Method 2: Execute Single Query
```powershell
# Run a single query without entering interactive mode
docker exec claims-postgres psql -U claims_user -d claims -c "SELECT COUNT(*) FROM claims.payer;"
```

### Method 3: Execute SQL File
```powershell
# Run a SQL file from your host machine
docker exec -i claims-postgres psql -U claims_user -d claims < your-query.sql

# Or copy the file content and pipe it
Get-Content your-query.sql | docker exec -i claims-postgres psql -U claims_user -d claims
```

### Method 4: Interactive Shell
```powershell
# Open container shell
docker exec -it claims-postgres sh

# Then inside container:
psql -U claims_user -d claims
```

## Useful psql Commands

Once inside psql (`docker exec -it claims-postgres psql -U claims_user -d claims`):

```
\dt              # List all tables in current schema
\dt claims.*     # List all tables in claims schema
\d table_name    # Describe table structure
\du              # List users/roles
\l               # List databases
\dn              # List schemas
\d+ table_name   # Detailed table info with sizes
\q               # Quit psql
\?               # Show help
```

## Common Query Examples

### Check Table Row Counts
```powershell
docker exec claims-postgres psql -U claims_user -d claims -c "SELECT schemaname, relname, n_live_tup FROM pg_stat_user_tables WHERE schemaname = 'claims' ORDER BY n_live_tup DESC LIMIT 10;"
```

### Check Refdata Tables
```powershell
docker exec claims-postgres psql -U claims_user -d claims -c "SELECT 'payers' as table_name, COUNT(*) FROM claims_ref.payer UNION ALL SELECT 'facilities', COUNT(*) FROM claims_ref.facility UNION ALL SELECT 'providers', COUNT(*) FROM claims_ref.provider;"
```

### Check Active Connections
```powershell
docker exec claims-postgres psql -U claims_user -d claims -c "SELECT count(*), state FROM pg_stat_activity WHERE datname = 'claims' GROUP BY state;"
```

### View Database Size
```powershell
docker exec claims-postgres psql -U claims_user -d claims -c "SELECT pg_size_pretty(pg_database_size('claims')) as db_size;"
```

### Run Multi-line Query (using here-string in PowerShell)
```powershell
$query = @"
SELECT 
    schemaname,
    tablename,
    n_live_tup
FROM pg_stat_user_tables
WHERE schemaname IN ('claims', 'claims_ref')
ORDER BY n_live_tup DESC;
"@

docker exec claims-postgres psql -U claims_user -d claims -c $query
```

## Environment Variables

If you need to use different credentials:
- User: `claims_user` (default)
- Password: `securepass` (default, set via POSTGRES_PASSWORD)
- Database: `claims`
- Host: `claims-postgres` (from within docker network), `localhost` (from host)

## Troubleshooting

### Connection Issues
```powershell
# Check if container is running
docker ps | Select-String "claims-postgres"

# Check logs
docker logs claims-postgres

# Test connection
docker exec claims-postgres pg_isready -U claims_user
```

### Permission Issues
If you get permission errors, make sure you're using the correct user:
```powershell
# Use the database owner
docker exec -it claims-postgres psql -U claims_user -d claims
```












