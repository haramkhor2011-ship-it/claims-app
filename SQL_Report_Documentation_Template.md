# SQL Report Documentation Template
## [Report Name] - [Date]

---

## 📋 Report Overview

### Basic Information
- **Report Name**: [Enter report name]
- **Business Purpose**: [Describe what business problem this report solves]
- **Target Audience**: [Who will use this report]
- **Frequency**: [How often is this report generated]
- **Created By**: [Developer name]
- **Created Date**: [Date]
- **Last Updated**: [Date]
- **Version**: [Version number]

### Report Description
[Provide a detailed description of what the report shows and why it's important for the business]

---

## 🏗️ Technical Architecture

### Database Components
| Component Type | Name | Purpose |
|----------------|------|---------|
| Base View | `[schema].[view_name]` | [Description] |
| Tab View A | `[schema].[view_name_a]` | [Description] |
| Tab View B | `[schema].[view_name_b]` | [Description] |
| API Function | `[schema].[function_name]` | [Description] |
| Helper Function | `[schema].[helper_function]` | [Description] |

### Data Sources
| Source Table | Schema | Purpose | Key Fields |
|--------------|--------|---------|------------|
| `[table_name]` | `[schema]` | [Description] | `[field1, field2, field3]` |
| `[table_name]` | `[schema]` | [Description] | `[field1, field2, field3]` |

### Relationships
```
[Create a diagram or describe the relationships between tables]
```

---

## 📊 Report Structure

### Tabs/Sections
1. **[Tab A Name]**: [Description of what this tab shows]
2. **[Tab B Name]**: [Description of what this tab shows]
3. **[Tab C Name]**: [Description of what this tab shows]

### Key Metrics
| Metric Name | Description | Calculation | Business Impact |
|-------------|-------------|-------------|-----------------|
| [Metric 1] | [Description] | [Formula] | [Why it matters] |
| [Metric 2] | [Description] | [Formula] | [Why it matters] |

---

## 🔍 Field Mappings

### Business Fields to Database Fields
| Business Field | Database Field | Source Table | Notes |
|----------------|----------------|--------------|-------|
| [Business Field] | `[database_field]` | `[table_name]` | [Any special logic or transformations] |
| [Business Field] | `[database_field]` | `[table_name]` | [Any special logic or transformations] |

### Calculated Fields
| Field Name | Calculation | Business Logic |
|------------|-------------|----------------|
| [Field Name] | `[SQL calculation]` | [Business explanation] |
| [Field Name] | `[SQL calculation]` | [Business explanation] |

---

## 🧮 Business Logic

### Key Calculations
1. **[Calculation Name]**:
   ```sql
   [SQL code for the calculation]
   ```
   - **Purpose**: [Why this calculation is needed]
   - **Business Rules**: [Any business rules that apply]

2. **[Calculation Name]**:
   ```sql
   [SQL code for the calculation]
   ```
   - **Purpose**: [Why this calculation is needed]
   - **Business Rules**: [Any business rules that apply]

### Filtering Logic
| Filter | Logic | Purpose |
|--------|-------|---------|
| [Filter Name] | `[SQL condition]` | [Why this filter is applied] |
| [Filter Name] | `[SQL condition]` | [Why this filter is applied] |

### Status Mappings
| Status Code | Status Text | Description |
|-------------|-------------|-------------|
| [Code] | [Text] | [Description] |
| [Code] | [Text] | [Description] |

---

## 🚀 Usage Instructions

### API Function Parameters
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `p_user_id` | TEXT | Yes | - | User ID for access control |
| `p_facility_codes` | TEXT[] | No | NULL | Filter by facility codes |
| `p_date_from` | TIMESTAMPTZ | No | 3 years ago | Start date filter |
| `p_date_to` | TIMESTAMPTZ | No | Now | End date filter |
| `p_limit` | INTEGER | No | 100 | Maximum records to return |
| `p_offset` | INTEGER | No | 0 | Records to skip |

### Example Usage
```sql
-- Basic usage
SELECT * FROM [schema].[function_name](
    'user123',                    -- p_user_id
    NULL,                         -- p_claim_key_ids
    ARRAY['FACILITY-001'],        -- p_facility_codes
    NULL,                         -- p_payer_codes
    NULL,                         -- p_receiver_ids
    '2024-01-01'::timestamptz,   -- p_date_from
    '2024-12-31'::timestamptz,   -- p_date_to
    NULL,                         -- p_year
    NULL,                         -- p_month
    FALSE,                        -- p_based_on_initial_net
    100,                          -- p_limit
    0,                            -- p_offset
    'encounter_start_date',       -- p_order_by
    'DESC'                        -- p_order_direction
);
```

### Direct View Access
```sql
-- Access specific tab
SELECT * FROM [schema].[view_name] 
WHERE [conditions]
ORDER BY [field] DESC
LIMIT 100;
```

---

## 🔧 Performance Considerations

### Indexes
| Index Name | Table | Columns | Purpose |
|------------|-------|---------|---------|
| `[index_name]` | `[table]` | `[columns]` | [Performance purpose] |
| `[index_name]` | `[table]` | `[columns]` | [Performance purpose] |

### Performance Tips
1. **Date Filtering**: Always use date filters to limit data volume
2. **Facility Filtering**: Use facility codes when possible for better performance
3. **Pagination**: Use LIMIT and OFFSET for large result sets
4. **Index Usage**: Monitor index usage with `pg_stat_user_indexes`

### Expected Performance
- **Small Dataset** (< 10K records): < 1 second
- **Medium Dataset** (10K-100K records): 1-5 seconds
- **Large Dataset** (> 100K records): 5-15 seconds

---

## 🧪 Testing & Validation

### Test Queries
```sql
-- Basic health check
SELECT COUNT(*) FROM [schema].[view_name];

-- Data quality check
SELECT 
    COUNT(*) as total_records,
    COUNT(CASE WHEN [critical_field] IS NULL THEN 1 END) as null_records
FROM [schema].[view_name];

-- Business logic validation
SELECT 
    [calculated_field],
    [expected_calculation],
    CASE 
        WHEN [calculated_field] = [expected_calculation] 
        THEN 'CORRECT' 
        ELSE 'ERROR' 
    END AS validation_status
FROM [schema].[view_name]
WHERE [calculated_field] != [expected_calculation];
```

### Validation Checklist
- [ ] All views created successfully
- [ ] All functions created successfully
- [ ] Sample data returns expected results
- [ ] Business logic calculations are correct
- [ ] No NULL values in critical fields
- [ ] Performance is acceptable
- [ ] Indexes are being used effectively
- [ ] API function handles all parameter combinations
- [ ] Tab logic is correct (no overlaps, proper filtering)
- [ ] Cross-validation with source data passes

---

## 📈 Monitoring & Maintenance

### Regular Checks
| Frequency | Check | Query |
|-----------|-------|-------|
| Daily | Data freshness | `SELECT MAX([date_field]) FROM [table]` |
| Weekly | Data quality | `[Data quality queries]` |
| Monthly | Performance | `[Performance monitoring queries]` |
| Quarterly | Business logic | `[Business logic validation queries]` |

### Performance Monitoring
```sql
-- Check query performance
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
WHERE query LIKE '%[report_name]%'
ORDER BY mean_time DESC;

-- Check index usage
SELECT 
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE indexname LIKE '%[report_name]%'
ORDER BY idx_scan DESC;
```

### Maintenance Tasks
1. **Weekly**: Run validation queries
2. **Monthly**: Review performance metrics
3. **Quarterly**: Update documentation
4. **Annually**: Review business logic

---

## 🚨 Troubleshooting

### Common Issues
| Issue | Symptoms | Solution |
|-------|----------|----------|
| Slow Performance | Queries taking > 30 seconds | Check indexes, add date filters |
| Missing Data | NULL values in expected fields | Check joins, verify source data |
| Incorrect Calculations | Business logic errors | Review calculation formulas |
| Access Denied | Permission errors | Check user grants and facility access |

### Error Messages
| Error | Cause | Solution |
|-------|-------|----------|
| `[Error message]` | [Cause] | [Solution] |
| `[Error message]` | [Cause] | [Solution] |

### Debug Queries
```sql
-- Check for data issues
SELECT 
    [field],
    COUNT(*) as count
FROM [table]
WHERE [condition]
GROUP BY [field]
ORDER BY count DESC;

-- Check join issues
SELECT 
    COUNT(*) as total_records,
    COUNT([joined_field]) as joined_records
FROM [main_table] m
LEFT JOIN [joined_table] j ON [join_condition];
```

---

## 📞 Support Information

### Contacts
- **Database Team**: [Contact information]
- **Business Analyst**: [Contact information]
- **Development Team**: [Contact information]

### Resources
- **Database Documentation**: [Link]
- **Business Requirements**: [Link]
- **Change Management**: [Link]

### Change History
| Date | Version | Changes | Author |
|------|---------|---------|--------|
| [Date] | [Version] | [Description] | [Author] |
| [Date] | [Version] | [Description] | [Author] |

---

## 📋 Appendix

### SQL Code
```sql
-- [Include the complete SQL implementation here]
```

### Sample Output
```
[Include sample output data here]
```

### Related Reports
- [Link to related report 1]
- [Link to related report 2]

---

*This documentation should be updated whenever the report structure or business logic changes.*
