# Core Tables Verification

**Generated:** 2025-10-25 18:57:19

## Summary

- **Source Files:** ../src/main/resources/db/claims_unified_ddl_fresh.sql
- **Docker File:** ../docker/db-init/02-core-tables.sql
- **Total Objects Expected:** 29
- **Total Objects Found:** 22
- **Completeness:** 65.5%
- **Overall Accuracy:** 61.0%

## Objects Overview

| Object Name | Type | Status | Completeness | Accuracy | Notes |
|-------------|------|--------|--------------|----------|-------|
| trg_diagnosis_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| trg_claim_tx_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| trg_remittance_activity_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| trg_remittance_claim_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| trg_encounter_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| trg_claim_contract_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| trg_claim_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| trg_claim_resubmission_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| trg_submission_tx_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| SCHEMA | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| trg_remittance_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| COLUMN | COMMENT | ✓ | 100.0% | 50.6% | Perfect match |
| trg_activity_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| VIEW | COMMENT | ✗ | 0.0% | 0.0% | Missing from Docker |
| trg_facility_dhpo_config_updated_at | TRIGGER | ✗ | 0.0% | 0.0% | Missing from Docker |
| trg_claim_payment_updated_at | TRIGGER | ? | 0.0% | 0.0% | Extra in Docker |
| trg_payer_performance_updated_at | TRIGGER | ? | 0.0% | 0.0% | Extra in Docker |
| trg_activity_summary_updated_at | TRIGGER | ? | 0.0% | 0.0% | Extra in Docker |
| FUNCTION | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| IF | INDEX | ✓ | 100.0% | 50.4% | Perfect match |
| ALL | GRANT | ✓ | 100.0% | 97.2% | Perfect match |
| trg_observation_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| trg_integration_toggle_updated_at | TRIGGER | ✗ | 0.0% | 0.0% | Missing from Docker |
| table | COMMENT | ✗ | 0.0% | 0.0% | Missing from Docker |
| trg_submission_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| trg_ingestion_file_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| trg_remittance_tx_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| column | COMMENT | ✗ | 0.0% | 0.0% | Missing from Docker |
| TABLE | COMMENT | ✓ | 100.0% | 70.9% | Perfect match |

## Missing Objects

- **SCHEMA** (GRANT)
- **VIEW** (COMMENT)
- **trg_facility_dhpo_config_updated_at** (TRIGGER)
- **FUNCTION** (GRANT)
- **trg_integration_toggle_updated_at** (TRIGGER)
- **table** (COMMENT)
- **column** (COMMENT)

## Extra Objects

- **trg_claim_payment_updated_at** (TRIGGER)
- **trg_payer_performance_updated_at** (TRIGGER)
- **trg_activity_summary_updated_at** (TRIGGER)

## Issues Found

### SCHEMA

- Object 'SCHEMA' exists in source but missing in Docker

### VIEW

- Object 'VIEW' exists in source but missing in Docker

### trg_facility_dhpo_config_updated_at

- Object 'trg_facility_dhpo_config_updated_at' exists in source but missing in Docker

### trg_claim_payment_updated_at

- Object 'trg_claim_payment_updated_at' exists in Docker but not in source

### trg_payer_performance_updated_at

- Object 'trg_payer_performance_updated_at' exists in Docker but not in source

### trg_activity_summary_updated_at

- Object 'trg_activity_summary_updated_at' exists in Docker but not in source

### FUNCTION

- Object 'FUNCTION' exists in source but missing in Docker

### trg_integration_toggle_updated_at

- Object 'trg_integration_toggle_updated_at' exists in source but missing in Docker

### table

- Object 'table' exists in source but missing in Docker

### column

- Object 'column' exists in source but missing in Docker

## Detailed Comparisons

### SCHEMA

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### VIEW

**Type:** COMMENT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### trg_facility_dhpo_config_updated_at

**Type:** TRIGGER
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### trg_claim_payment_updated_at

**Type:** TRIGGER
**Status:** EXTRA
**Completeness:** 0.0%
**Accuracy:** 0.0%

### trg_payer_performance_updated_at

**Type:** TRIGGER
**Status:** EXTRA
**Completeness:** 0.0%
**Accuracy:** 0.0%

### trg_activity_summary_updated_at

**Type:** TRIGGER
**Status:** EXTRA
**Completeness:** 0.0%
**Accuracy:** 0.0%

### FUNCTION

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### trg_integration_toggle_updated_at

**Type:** TRIGGER
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### table

**Type:** COMMENT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### column

**Type:** COMMENT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

