# Reference Data System Analysis

## How the RefData System Works

Based on the Java code analysis, here's how the reference data system operates:

### 1. **Bootstrap System** (`RefdataBootstrapRunner`)
- **Purpose**: Loads CSV files into `claims_ref.*` tables on application startup
- **Trigger**: Only runs when `claims.refdata.bootstrap.enabled = true`
- **What it does**: 
  - Reads CSV files from `classpath:refdata/`
  - Loads data into: payers, facilities, providers, clinicians, activity_codes, diagnosis_codes, denial_codes, contract_packages
  - Uses `RefdataCsvLoader` to perform the actual loading

### 2. **Auto-Insert System** (`RefCodeResolver`)
- **Purpose**: Dynamically creates reference data during claim processing
- **Trigger**: Always active, controlled by `claims.refdata.auto-insert` property
- **What it does**:
  - When processing claims, if a `provider_id`, `facility_id`, or `payer_id` doesn't exist in `claims_ref.*` tables
  - **If `auto-insert = true`**: Creates the missing reference record and returns the `ref_id`
  - **If `auto-insert = false`**: Only audits the missing code, returns `null` (so `ref_id` stays `NULL`)

### 3. **Key Configuration Properties**

#### `claims.refdata.bootstrap.enabled`
- **Controls**: Whether to load CSV files on startup
- **Default**: `false` (from `RefdataBootstrapProperties.java` line 13)
- **Effect**: 
  - `true` = Load CSV files into `claims_ref.*` tables on startup
  - `false` = Skip CSV loading on startup

#### `claims.refdata.auto-insert`
- **Controls**: Whether to create missing reference data during claim processing
- **Default**: `true` (from `RefDataProperties.java` line 8)
- **Effect**:
  - `true` = Create missing reference records and populate `ref_id` columns
  - `false` = Only audit missing codes, leave `ref_id` columns as `NULL`

## Current Configuration Analysis

### Your Current Settings:
```yaml
# application.yml (base)
claims:
  refdata:
    bootstrap:
      enabled: false                           # ✅ Correct - no CSV loading
    auto-insert: true                          # ✅ Correct - populate ref_id

# application-prod.yml (your active profile)
claims:
  refdata:
    auto-insert: true                          # ✅ Correct - populate ref_id
  bootstrap:
    enabled: false                             # ✅ Correct - no CSV loading
```

## What This Means for Your Application

### ✅ **What WILL Happen:**
1. **No CSV Loading**: Application won't read CSV files on startup (faster startup)
2. **Dynamic ref_id Population**: During claim processing, missing reference data will be created automatically
3. **Proper ref_id Columns**: Your balance amount report will have populated `ref_id` columns

### ✅ **How It Works in Practice:**
1. **Claim Ingestion**: Process claim with `provider_id = "DHA-P-12345"`
2. **RefCodeResolver Check**: Look for `DHA-P-12345` in `claims_ref.provider`
3. **Auto-Insert**: If not found, create record: `{provider_code: "DHA-P-12345", name: "DHA-P-12345", status: "ACTIVE"}`
4. **Return ref_id**: Set `provider_ref_id` in claim table to the new record's ID
5. **Result**: Both `provider_id` and `provider_ref_id` are populated

## Final Recommendation

### ✅ **Keep Current Configuration:**
```yaml
claims:
  refdata:
    bootstrap:
      enabled: false                    # ✅ No CSV loading on startup
    auto-insert: true                   # ✅ Populate ref_id during persist
```

### 🎯 **Why This is Perfect:**
1. **Performance**: No CSV processing on startup
2. **Data Integrity**: Reference data created from actual claim data
3. **Report Compatibility**: Balance amount report will have populated `ref_id` columns
4. **Dynamic**: Only creates reference data for codes that actually exist in claims
5. **Audit Trail**: All missing codes are audited in `claims.code_discovery_audit`

## No Changes Needed!

Your current configuration is **perfect** for your use case. The system will:
- ✅ Not load CSV files on startup
- ✅ Automatically populate `ref_id` columns during claim processing
- ✅ Create reference data dynamically as needed
- ✅ Provide proper data for your balance amount report
