# Materialized Views Setup Guide

## Problem

The materialized views defined in `sub_second_materialized_views.sql` have not been created in your database. This is why all queries to these views return empty results or errors.

## Root Cause

The materialized view creation script (`src/main/resources/db/reports_sql/sub_second_materialized_views.sql`) is **NOT** included in the main database DDL file (`claims_unified_ddl_fresh.sql`), so it must be run separately.

## Solution

You need to execute the materialized view creation script. Here are your options:

### Option 1: Run via psql (Command Line)

If you have psql installed and in your PATH:

```bash
psql -U claims_user -d claims -f src/main/resources/db/reports_sql/sub_second_materialized_views.sql
```

### Option 2: Run via Database Client (pgAdmin, DBeaver, etc.)

1. Open your preferred PostgreSQL client
2. Connect to your `claims` database
3. Open the file: `src/main/resources/db/reports_sql/sub_second_materialized_views.sql`
4. Execute the entire script
5. Wait for completion (5-15 minutes depending on data volume)

### Option 3: Run via Java Application

We can create a Spring Boot command-line runner to execute the script:

```bash
mvn spring-boot:run -Dspring-boot.run.arguments="--init.materialized-views=true" -Dspring-boot.run.profiles=local
```

(This requires creating an initialization service - let me know if you need this)

## Prerequisites

Before running the materialized view script, ensure:

1. ✅ Database schema is created (`claims` and `claims_ref` schemas exist)
2. ✅ Base tables have data:
   - `claims.claim_key`
   - `claims.claim`
   - `claims.encounter`
   - `claims.activity`
   - `claims.remittance_claim`
   - `claims.remittance_activity`

3. ✅ Reference data is populated:
   - `claims_ref.provider`
   - `claims_ref.payer`
   - `claims_ref.facility`
   - `claims_ref.clinician`

## Verification Steps

After running the script, verify the materialized views were created:

### Step 1: Check if views exist

```sql
SELECT 
    matviewname,
    pg_size_pretty(pg_total_relation_size('claims.'||matviewname)) as size
FROM pg_matviews 
WHERE schemaname = 'claims' AND matviewname LIKE 'mv_%'
ORDER BY matviewname;
```

Expected output: 10 materialized views

### Step 2: Check row counts

```sql
SELECT 'mv_balance_amount_summary' as view_name, COUNT(*) as row_count FROM claims.mv_balance_amount_summary
UNION ALL SELECT 'mv_remittance_advice_summary', COUNT(*) FROM claims.mv_remittance_advice_summary
UNION ALL SELECT 'mv_doctor_denial_summary', COUNT(*) FROM claims.mv_doctor_denial_summary
UNION ALL SELECT 'mv_claims_monthly_agg', COUNT(*) FROM claims.mv_claims_monthly_agg
UNION ALL SELECT 'mv_claim_details_complete', COUNT(*) FROM claims.mv_claim_details_complete
UNION ALL SELECT 'mv_resubmission_cycles', COUNT(*) FROM claims.mv_resubmission_cycles
UNION ALL SELECT 'mv_remittances_resubmission_activity_level', COUNT(*) FROM claims.mv_remittances_resubmission_activity_level
UNION ALL SELECT 'mv_rejected_claims_summary', COUNT(*) FROM claims.mv_rejected_claims_summary
UNION ALL SELECT 'mv_claim_summary_payerwise', COUNT(*) FROM claims.mv_claim_summary_payerwise
UNION ALL SELECT 'mv_claim_summary_encounterwise', COUNT(*) FROM claims.mv_claim_summary_encounterwise
ORDER BY view_name;
```

**If any view has 0 rows**: This likely means your base tables are empty or reference data is not populated.

### Step 3: Sample data

```sql
SELECT * FROM claims.mv_balance_amount_summary LIMIT 5;
```

## Troubleshooting

### Problem: All materialized views have 0 rows

**Diagnosis**: Check if your base tables have data

```sql
SELECT 'claim' as table_name, COUNT(*) as row_count FROM claims.claim
UNION ALL SELECT 'encounter', COUNT(*) FROM claims.encounter
UNION ALL SELECT 'activity', COUNT(*) FROM claims.activity;
```

**Solution**: 
- If counts are 0, you need to ingest claim data first
- Place claim XML files in `data/ready/` directory
- Start the application to process them

### Problem: Some materialized views have data, others are empty

**Diagnosis**: Check JOIN conditions and reference data

```sql
-- Check if ref_id columns are populated
SELECT 
    COUNT(*) as total_claims,
    COUNT(provider_ref_id) as has_provider_ref,
    COUNT(payer_ref_id) as has_payer_ref
FROM claims.claim;
```

**Solution**:
- Enable auto-insert for reference data: `claims.refdata.auto-insert=true` in application.yml
- Or manually run reference data population scripts

### Problem: Script fails with "materialized view already exists"

**Solution**: The views were already created. Just refresh them:

```sql
SELECT refresh_report_mvs_subsecond();
```

## Maintenance

### Refresh Materialized Views

After new data is ingested, refresh the materialized views:

```sql
-- Refresh all views
SELECT refresh_report_mvs_subsecond();

-- Or refresh individual views
SELECT refresh_balance_amount_mv();
SELECT refresh_remittance_advice_mv();
```

### Recommended Refresh Schedule

- **Real-time**: After each large batch import
- **Scheduled**: Every 4 hours during business hours
- **Daily**: Full refresh during maintenance window

### Set up automated refresh (PostgreSQL cron extension)

```sql
-- Install pg_cron if not already installed
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule refresh every 4 hours
SELECT cron.schedule('refresh-report-mvs', '0 */4 * * *', $$SELECT refresh_report_mvs_subsecond()$$);
```

## Performance Expectations

After materialized views are populated and in use:

- **Balance Amount Report**: 0.5-1.5 seconds (from 30-60 seconds)
- **Remittance Advice**: 0.3-0.8 seconds (from 15-25 seconds)
- **Resubmission Report**: 0.8-2.0 seconds (from 45-90 seconds)
- **Doctor Denial Report**: 0.4-1.0 seconds (from 25-40 seconds)
- **Rejected Claims Report**: 0.4-1.2 seconds (from 15-45 seconds)

## Summary

1. **Run the script**: Execute `sub_second_materialized_views.sql` in your database
2. **Verify creation**: Check that 10 materialized views were created
3. **Check row counts**: Ensure views have data
4. **Test reports**: Your reports should now return results
5. **Set up refresh**: Schedule regular refreshes for updated data

