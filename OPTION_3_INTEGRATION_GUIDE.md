# OPTION 3 INTEGRATION GUIDE - EXISTING SERVICES

## Overview
This guide shows how to integrate Option 3 into your existing report services without creating new classes or YML files.

## Integration Pattern

### **1. Add Option3ToggleRepository Dependency**
```java
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class YourReportService {
    
    private final DataSource dataSource;
    private final Option3ToggleRepository toggleRepository; // ADD THIS
    
    // ... existing methods
}
```

### **2. Update Method to Use Option 3**
```java
public List<Map<String, Object>> yourReportMethod(
        String userId,
        // ... other parameters
) {
    // OPTION 3: Determine whether to use MVs or traditional views
    boolean useMv = toggleRepository.isMvEnabled() || toggleRepository.isSubSecondModeEnabled();
    String tabName = toggleRepository.getDefaultTab("your-report-type");
    
    log.info("Your Report - useMv: {}, tabName: {}", useMv, tabName);
    
    // Use Option 3 function with dynamic data source selection
    String sql = """
        SELECT * FROM claims.get_your_report_function(
            p_use_mv := ?,
            p_tab_name := ?,
            p_user_id := ?,
            -- ... other parameters
        )
    """;
    
    try (Connection conn = dataSource.getConnection();
         PreparedStatement stmt = conn.prepareStatement(sql)) {
        
        int i = 1;
        // OPTION 3: Set useMv and tabName parameters first
        stmt.setBoolean(i++, useMv);
        stmt.setString(i++, tabName);
        stmt.setString(i++, userId);
        // ... set other parameters
        
        // ... execute query and process results
        
        log.info("Retrieved {} rows using Option 3 (useMv: {}, tabName: {})", 
            results.size(), useMv, tabName);
    }
}
```

## Services to Update

### **1. ClaimDetailsWithActivityReportService**
- **Function**: `get_claim_details_with_activity`
- **Report Type**: `claim-details`
- **Default Tab**: `details`

### **2. ClaimSummaryMonthwiseReportService**
- **Function**: `get_claim_summary_monthwise_params`
- **Report Type**: `claim-summary`
- **Default Tab**: `monthwise`

### **3. DoctorDenialReportService**
- **Function**: `get_doctor_denial_report`
- **Report Type**: `doctor-denial`
- **Default Tab**: `high_denial`

### **4. RejectedClaimsReportService**
- **Function**: `get_rejected_claims_summary`
- **Report Type**: `rejected-claims`
- **Default Tab**: `summary`

### **5. RemittanceAdvicePayerwiseReportService**
- **Function**: `get_remittance_advice_report_params`
- **Report Type**: `remittance-advice`
- **Default Tab**: `header`

### **6. RemittancesResubmissionReportService**
- **Function**: `get_remittances_resubmission_activity_level`
- **Report Type**: `resubmission`
- **Default Tab**: `activity_level`

## Database Toggle Management

### **Enable MVs via Database**
```sql
-- Enable MVs for all reports
UPDATE claims.system_settings 
SET setting_value = 'true' 
WHERE setting_key = 'is_mv_enabled';

-- Enable sub-second performance mode
UPDATE claims.system_settings 
SET setting_value = 'true' 
WHERE setting_key = 'is_sub_second_mode_enabled';
```

### **Disable MVs via Database**
```sql
-- Disable MVs (use traditional views)
UPDATE claims.system_settings 
SET setting_value = 'false' 
WHERE setting_key = 'is_mv_enabled';

-- Disable sub-second performance mode
UPDATE claims.system_settings 
SET setting_value = 'false' 
WHERE setting_key = 'is_sub_second_mode_enabled';
```

## Admin API Endpoints

### **Get Current Toggles**
```bash
GET /api/v1/admin/option3/toggles
```

### **Enable MVs**
```bash
POST /api/v1/admin/option3/mv-enabled
Content-Type: application/json

{
  "enabled": true
}
```

### **Enable Sub-Second Mode**
```bash
POST /api/v1/admin/option3/sub-second-mode
Content-Type: application/json

{
  "enabled": true
}
```

### **Bulk Enable All MVs**
```bash
POST /api/v1/admin/option3/enable-all-mvs
```

### **Bulk Disable All MVs**
```bash
POST /api/v1/admin/option3/disable-all-mvs
```

## Configuration

### **Application Properties**
```yaml
claims:
  reports:
    option3:
      enabled: true                           # Enable Option 3 functionality
      cache-ttl-ms: 300000                    # Toggle cache TTL (5 minutes)
      fallback-to-traditional: true           # Fallback to traditional views if MVs fail
```

## Benefits

### **1. No New Classes Required**
- Uses existing service structure
- Minimal code changes
- Backward compatible

### **2. Runtime Toggle Control**
- Switch between traditional views and MVs without restart
- Database-driven configuration
- Cached for performance

### **3. Automatic Fallback**
- Falls back to traditional views if MVs fail
- Graceful degradation
- No service interruption

### **4. Performance Monitoring**
- Logs which data source is being used
- Toggle status visibility
- Health check endpoints

## Testing

### **1. Test Traditional Views**
```bash
# Disable MVs
POST /api/v1/admin/option3/disable-all-mvs

# Test your report endpoint
GET /api/v1/reports/your-report
```

### **2. Test MVs**
```bash
# Enable MVs
POST /api/v1/admin/option3/enable-all-mvs

# Test your report endpoint
GET /api/v1/reports/your-report
```

### **3. Verify Logs**
```
Your Report - useMv: true, tabName: details
Retrieved 150 rows using Option 3 (useMv: true, tabName: details)
```

## Conclusion

Option 3 integration is simple and requires minimal changes to existing services. The database toggle provides runtime control without requiring application restarts or new configuration files.

