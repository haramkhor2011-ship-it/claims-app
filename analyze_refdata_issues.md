# Refdata Bootstrap Issues Analysis

## Problem
Refdata bootstrap was disabled (`CLAIMS_REFDATA_BOOTSTRAP_ENABLED: "false"`) because it failed with:
```
ERROR: there is no unique or exclusion constraint matching the ON CONFLICT specification
```

## Root Cause Analysis

### Issues Found:

1. **activity_code table:**
   - Code uses: `ON CONFLICT (code, code_system)`
   - Actual constraint: `uq_activity_code` on `(code, type)`
   - **Mismatch**: Uses `code_system` but constraint is on `type`

2. **diagnosis_code table:**
   - Code uses: `ON CONFLICT (code, code_system)`
   - Actual constraint: `uq_diagnosis_code` on `(code, description)`
   - **Mismatch**: Uses `code_system` but constraint is on `description`

3. **contract_package table:**
   - Code tries to insert into `claims_ref.contract_package`
   - **Issue**: Table doesn't exist in the database!












