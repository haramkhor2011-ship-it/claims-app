# Refdata Bootstrap Fix

## Why Refdata Didn't Populate

The refdata bootstrap was **disabled** (`CLAIMS_REFDATA_BOOTSTRAP_ENABLED: "false"` in docker-compose.yml) because it was failing during startup with:

```
ERROR: there is no unique or exclusion constraint matching the ON CONFLICT specification
```

## Root Causes

### 1. **activity_code** - Mismatched ON CONFLICT Clause
- **Code uses**: `ON CONFLICT (code, code_system)`
- **Actual constraint**: `UNIQUE (code, type)`
- **Location**: `RefdataCsvLoader.java` line 109

### 2. **diagnosis_code** - Mismatched ON CONFLICT Clause  
- **Code uses**: `ON CONFLICT (code, code_system)`
- **Actual constraint**: `UNIQUE (code, description)`
- **Location**: `RefdataCsvLoader.java` line 128

### 3. **contract_package** - Missing Table
- **Code tries to**: Insert into `claims_ref.contract_package`
- **Reality**: Table doesn't exist in the database schema
- **Location**: `RefdataCsvLoader.java` line 159

## Solutions

### Option 1: Fix the Code (Recommended)

1. **Fix activity_code ON CONFLICT**:
   ```java
   // Change from:
   on conflict (code, code_system) do update
   // To:
   on conflict (code, type) do update
   ```

2. **Fix diagnosis_code ON CONFLICT**:
   ```java
   // Change from:
   on conflict (code, code_system) do update
   // To:
   on conflict (code, description) do update
   ```

3. **Handle contract_package**:
   - Either create the table in `03-ref-data-tables.sql`
   - Or comment out `loadContractPackages()` if not needed

### Option 2: Fix the Database Constraints (Alternative)

Add missing constraints to match what the code expects:

1. Add `UNIQUE (code, code_system)` to `activity_code`
2. Add `UNIQUE (code, code_system)` to `diagnosis_code`
3. Create `contract_package` table

## Current Status

- Bootstrap is **disabled** via `CLAIMS_REFDATA_BOOTSTRAP_ENABLED: "false"`
- Reference data tables are **empty** (0 rows except seed data)
- Application relies on **auto-insert** mechanism (creates refdata during claim processing)

## To Re-enable Bootstrap

After fixing the issues above:

1. Remove or set `CLAIMS_REFDATA_BOOTSTRAP_ENABLED: "true"` in docker-compose.yml
2. Restart the application
3. Bootstrap will load CSV files from `src/main/resources/refdata/`












