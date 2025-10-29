# DHPO Configuration Verification

**Generated:** 2025-10-25 18:57:19

## Summary

- **Source Files:** ../src/main/resources/db/dhpo_config.sql
- **Docker File:** ../docker/db-init/04-dhpo-config.sql
- **Total Objects Expected:** 6
- **Total Objects Found:** 6
- **Completeness:** 50.0%
- **Overall Accuracy:** 35.1%

## Objects Overview

| Object Name | Type | Status | Completeness | Accuracy | Notes |
|-------------|------|--------|--------------|----------|-------|
| trg_facility_dhpo_config_updated_at | TRIGGER | ? | 0.0% | 0.0% | Extra in Docker |
| trg_integration_toggle_updated_at | TRIGGER | ? | 0.0% | 0.0% | Extra in Docker |
| claims.integration_toggle | GRANT | ✓ | 100.0% | 63.0% | Perfect match |
| COLUMN | COMMENT | ✓ | 100.0% | 100.0% | Perfect match |
| IF | INDEX | ? | 0.0% | 0.0% | Extra in Docker |
| TABLE | COMMENT | ✓ | 100.0% | 47.8% | Perfect match |

## Extra Objects

- **trg_facility_dhpo_config_updated_at** (TRIGGER)
- **trg_integration_toggle_updated_at** (TRIGGER)
- **IF** (INDEX)

## Issues Found

### trg_facility_dhpo_config_updated_at

- Object 'trg_facility_dhpo_config_updated_at' exists in Docker but not in source

### trg_integration_toggle_updated_at

- Object 'trg_integration_toggle_updated_at' exists in Docker but not in source

### IF

- Object 'IF' exists in Docker but not in source

## Detailed Comparisons

### trg_facility_dhpo_config_updated_at

**Type:** TRIGGER
**Status:** EXTRA
**Completeness:** 0.0%
**Accuracy:** 0.0%

### trg_integration_toggle_updated_at

**Type:** TRIGGER
**Status:** EXTRA
**Completeness:** 0.0%
**Accuracy:** 0.0%

### IF

**Type:** INDEX
**Status:** EXTRA
**Completeness:** 0.0%
**Accuracy:** 0.0%

