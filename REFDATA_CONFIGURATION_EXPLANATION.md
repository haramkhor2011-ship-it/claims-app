# Reference Data Configuration Explanation

## Current Configuration (Fixed)

### application.yml (Base Configuration)
```yaml
claims:
  refdata:
    bootstrap:
      enabled: false                           # profiles override
      strict: false
      location: classpath:refdata/
      delimiter: ','
      batch-size: 500
    auto-insert: true                          # profiles override
```

### application-prod.yml (Production Profile - Your Active Profile)
```yaml
claims:
  refdata:
    auto-insert: true                    # ENABLED: Populate ref_id columns during persist
  bootstrap:
    enabled: false                       # DISABLED: Don't read CSV files on startup, only populate ref_id during persist
    csv-path: "classpath:refdata/"
```

### application-soap.yml (SOAP Profile - Your Active Profile)
- **No refdata configuration**: Inherits from base application.yml
- **Result**: Uses base configuration with `auto-insert: true` and `bootstrap.enabled: false`

## What This Configuration Does

### ✅ Bootstrap: DISABLED (`enabled: false`)
- **What it does**: Prevents reading CSV files from `classpath:refdata/` on application startup
- **Why disabled**: We don't want to populate `claims_ref.*` tables from CSV files every time the app starts
- **Result**: No automatic CSV reading and insertion into reference tables

### ✅ Auto-Insert: ENABLED (`auto-insert: true`)
- **What it does**: Automatically populates `ref_id` columns during the persist process
- **How it works**: When persisting claims, if a `provider_id`, `facility_id`, or `payer_id` doesn't exist in `claims_ref.*` tables, it will:
  1. Insert the missing reference data into `claims_ref.provider`, `claims_ref.facility`, or `claims_ref.payer`
  2. Set the corresponding `ref_id` column in the main tables
- **Result**: `ref_id` columns get populated automatically during claim ingestion

## Benefits of This Configuration

1. **No CSV Reading**: Application doesn't read CSV files on startup (faster startup)
2. **Automatic ref_id Population**: `ref_id` columns get populated during persist process
3. **Dynamic Reference Data**: Reference data is created as needed from actual claim data
4. **No Duplicate Data**: Only creates reference data for IDs that actually exist in claims
5. **Performance**: No unnecessary CSV processing on every startup

## How It Works in Practice

1. **Claim Ingestion**: When a claim is processed with `provider_id = "DHA-P-12345"`
2. **Auto-Insert Check**: System checks if `DHA-P-12345` exists in `claims_ref.provider`
3. **Insert if Missing**: If not found, inserts `{provider_code: "DHA-P-12345", name: "DHA-P-12345"}` into `claims_ref.provider`
4. **Set ref_id**: Sets `provider_ref_id` in the claim table to the newly created reference record ID
5. **Result**: Both the original `provider_id` and the new `provider_ref_id` are populated

## For Your Balance Amount Report

This configuration ensures that:
- Your balance amount report views will have populated `ref_id` columns
- Reference data joins will work properly
- No need to manually populate `claims_ref.*` tables from CSV files
- Reference data is created dynamically from actual claim data
