# Functions and Procedures Verification

**Generated:** 2025-10-25 18:57:22

## Summary

- **Source Files:** ../src/main/resources/db/claim_payment_functions.sql
- **Docker File:** ../docker/db-init/08-functions-procedures.sql
- **Total Objects Expected:** 3
- **Total Objects Found:** 2
- **Completeness:** 66.7%
- **Overall Accuracy:** 34.6%

## Objects Overview

| Object Name | Type | Status | Completeness | Accuracy | Notes |
|-------------|------|--------|--------------|----------|-------|
| trg_update_claim_payment_remittance_activity | TRIGGER | ✗ | 0.0% | 0.0% | Missing from Docker |
| TRIGGER | COMMENT | ✓ | 100.0% | 52.4% | Perfect match |
| FUNCTION | COMMENT | ✓ | 100.0% | 51.4% | Perfect match |

## Missing Objects

- **trg_update_claim_payment_remittance_activity** (TRIGGER)

## Issues Found

### trg_update_claim_payment_remittance_activity

- Object 'trg_update_claim_payment_remittance_activity' exists in source but missing in Docker

## Detailed Comparisons

### trg_update_claim_payment_remittance_activity

**Type:** TRIGGER
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

