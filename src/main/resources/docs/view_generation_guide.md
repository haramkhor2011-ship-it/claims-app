# View and Materialized View Generation from JSON Mapping

## Overview

This guide explains how to use the `report_columns_xml_mappings.json` file to generate database views and materialized views for your claims reporting system.

## JSON Mapping Structure

The JSON file contains comprehensive field mappings with the following structure:

```json
{
  "filename": "Xml fileds mapping.xlsx",
  "sheets": [
    {
      "id": "0",
      "name": "Sheet1",
      "headers": [
        "Report Column",
        "Submission XML path",
        "Remittance XML path",
        "Notes / derivation",
        "Cursor Analysis",
        "Submission DB Path",
        "Remittance DB Path",
        "Data Type",
        "Best Path",
        "AI Analysis"
      ],
      "rows": [
        {
          "Report Column": "ActivityID",
          "Submission XML path": "Claim/Activity/ID",
          "Remittance XML path": "Claim/Activity/ID",
          "Notes / derivation": "Direct element: activity/line identifier",
          "Submission DB Path": "claims.activity.activity_id",
          "Remittance DB Path": "claims.remittance_activity.activity_id",
          "Data Type": "text",
          "Best Path": "claims.activity.activity_id",
          "AI Analysis": "Unique identifier for each activity within a claim"
        }
      ]
    }
  ]
}
```

## Generated Files

### 1. Static View Generation (`generate_views_from_mapping.sql`)

This file contains pre-built views based on the JSON mapping:

- **`v_comprehensive_claims_report`**: Main comprehensive view with all fields
- **`v_balance_amount_report`**: Balance amount specific view
- **`v_rejected_claims_report`**: Rejected claims specific view
- **`v_remittance_advice_report`**: Remittance advice specific view

### 2. Dynamic View Generation (`dynamic_view_generator.sql`)

This file provides functions for dynamic view creation:

- **`claims.populate_mappings_from_json()`**: Populate mapping table from JSON
- **`claims.create_all_standard_views()`**: Create all standard views and MVs
- **`claims.execute_dynamic_view_creation()`**: Create custom views
- **`claims.create_materialized_view_from_view()`**: Create MVs from views

### 3. Java Utility (`ReportViewGenerator.java`)

Java class for programmatic view generation:

- **`loadColumnMappings()`**: Load mappings from JSON file
- **`generateComprehensiveViewSql()`**: Generate comprehensive view SQL
- **`generateBalanceAmountViewSql()`**: Generate balance amount view SQL
- **`generateCompleteSqlScript()`**: Generate complete SQL script

### 4. REST API (`ReportViewGenerationController.java`)

REST endpoints for view generation:

- **`GET /api/reports/views/mappings`**: Get all column mappings
- **`GET /api/reports/views/sql/comprehensive`**: Generate comprehensive view SQL
- **`GET /api/reports/views/sql/balance-amount`**: Generate balance amount view SQL
- **`GET /api/reports/views/sql/complete`**: Generate complete SQL script

## Usage Examples

### 1. Using Static SQL Files

```sql
-- Execute the static view generation
\i src/main/resources/db/generate_views_from_mapping.sql

-- Use the generated views
SELECT * FROM claims.v_comprehensive_claims_report LIMIT 10;
SELECT * FROM claims.v_balance_amount_report WHERE pending_amt > 1000;
```

### 2. Using Dynamic Functions

```sql
-- Populate mappings and create all views
SELECT claims.create_all_standard_views();

-- Create a custom view
SELECT claims.execute_dynamic_view_creation('v_custom_report', 'comprehensive', TRUE);

-- Create materialized view from existing view
SELECT claims.create_materialized_view_from_view('mv_custom_report', 'v_custom_report', ARRAY['claim_key_id']);
```

### 3. Using Java API

```java
@Autowired
private ReportViewGenerator reportViewGenerator;

// Load mappings
List<ColumnMapping> mappings = reportViewGenerator.loadColumnMappings();

// Generate SQL
String sql = reportViewGenerator.generateCompleteSqlScript();

// Execute SQL (using JdbcTemplate or similar)
jdbcTemplate.execute(sql);
```

### 4. Using REST API

```bash
# Get column mappings
curl -X GET "http://localhost:8080/api/reports/views/mappings"

# Generate comprehensive view SQL
curl -X GET "http://localhost:8080/api/reports/views/sql/comprehensive"

# Generate complete SQL script
curl -X GET "http://localhost:8080/api/reports/views/sql/complete"
```

## Key Features

### 1. Field Mapping

The system maps JSON fields to database columns:

- **Report Column**: User-friendly column name
- **Submission DB Path**: Database path for submission data
- **Remittance DB Path**: Database path for remittance data
- **Best Path**: Recommended database path
- **Data Type**: PostgreSQL data type

### 2. Derived Fields

Handles calculated fields like:

- **Outstanding Balance**: `claims.claim.net - sum(claims.remittance_activity.payment_amount)`
- **Aging Days**: `current_date - claims.encounter.start_at`
- **Payment Status**: Derived from payment amounts

### 3. Performance Optimization

- **Materialized Views**: Pre-computed views for better performance
- **Indexes**: Automatic index creation on key columns
- **Concurrent Refresh**: Non-blocking materialized view refresh

### 4. Security

- **Row Level Security**: Views respect user facility access
- **Parameterized Queries**: SQL injection protection
- **Access Control**: Proper grants and permissions

## Best Practices

### 1. View Naming Convention

- **Views**: `v_[report_type]_[description]`
- **Materialized Views**: `mv_[report_type]_[description]`
- **Generated Views**: `v_[report_type]_generated`

### 2. Data Type Mapping

| JSON Data Type | PostgreSQL Type |
|----------------|-----------------|
| text | TEXT |
| integer | INTEGER |
| numeric(14,2) | NUMERIC(14,2) |
| timestamptz | TIMESTAMPTZ |
| boolean | BOOLEAN |
| array of text | TEXT[] |

### 3. Refresh Strategy

```sql
-- Daily refresh for materialized views
SELECT cron.schedule('refresh-mvs', '0 2 * * *', 'SELECT claims.refresh_all_report_materialized_views();');
```

### 4. Monitoring

```sql
-- Check view usage
SELECT schemaname, viewname, definition 
FROM pg_views 
WHERE schemaname = 'claims' 
AND viewname LIKE '%generated%';

-- Check materialized view refresh status
SELECT schemaname, matviewname, hasindexes, ispopulated
FROM pg_matviews 
WHERE schemaname = 'claims';
```

## Troubleshooting

### 1. Common Issues

- **JSON Parsing Errors**: Check JSON file format and encoding
- **Column Name Conflicts**: Ensure unique column names in views
- **Performance Issues**: Use materialized views for large datasets
- **Permission Errors**: Check grants and user permissions

### 2. Debugging

```sql
-- Check mapping table
SELECT * FROM claims.report_column_mappings ORDER BY report_column;

-- Test view generation
SELECT claims.create_dynamic_view('v_test_view', 'comprehensive', TRUE);

-- Check generated SQL
SELECT claims.generate_view_columns('v_test_view', TRUE);
```

## Future Enhancements

1. **Automated Refresh**: Scheduled materialized view refresh
2. **Version Control**: Track view changes and versions
3. **Performance Metrics**: Monitor view performance and usage
4. **Custom Mappings**: Allow custom field mappings
5. **Export Options**: Export views to different formats

## Conclusion

The JSON mapping approach provides a flexible and maintainable way to generate database views and materialized views. It ensures consistency between XML schemas and database structures while providing performance optimization through materialized views.

For questions or issues, refer to the generated SQL files or use the REST API endpoints for programmatic access.
