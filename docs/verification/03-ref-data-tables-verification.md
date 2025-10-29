# Reference Data Tables Verification

**Generated:** 2025-10-25 18:57:19

## Summary

- **Source Files:** ../src/main/resources/db/claims_ref_ddl.sql
- **Docker File:** ../docker/db-init/03-ref-data-tables.sql
- **Total Objects Expected:** 8
- **Total Objects Found:** 4
- **Completeness:** 0.0%
- **Overall Accuracy:** 0.0%

## Objects Overview

| Object Name | Type | Status | Completeness | Accuracy | Notes |
|-------------|------|--------|--------------|----------|-------|
| if | INDEX | ✗ | 0.0% | 0.0% | Missing from Docker |
| table | COMMENT | ✗ | 0.0% | 0.0% | Missing from Docker |
| all | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| COLUMN | COMMENT | ? | 0.0% | 0.0% | Extra in Docker |
| ALL | GRANT | ? | 0.0% | 0.0% | Extra in Docker |
| IF | INDEX | ? | 0.0% | 0.0% | Extra in Docker |
| column | COMMENT | ✗ | 0.0% | 0.0% | Missing from Docker |
| TABLE | COMMENT | ? | 0.0% | 0.0% | Extra in Docker |

## Missing Objects

- **if** (INDEX)
- **table** (COMMENT)
- **all** (GRANT)
- **column** (COMMENT)

## Extra Objects

- **COLUMN** (COMMENT)
- **ALL** (GRANT)
- **IF** (INDEX)
- **TABLE** (COMMENT)

## Issues Found

### if

- Object 'if' exists in source but missing in Docker

### table

- Object 'table' exists in source but missing in Docker

### all

- Object 'all' exists in source but missing in Docker

### COLUMN

- Object 'COLUMN' exists in Docker but not in source

### ALL

- Object 'ALL' exists in Docker but not in source

### IF

- Object 'IF' exists in Docker but not in source

### column

- Object 'column' exists in source but missing in Docker

### TABLE

- Object 'TABLE' exists in Docker but not in source

## Detailed Comparisons

### if

**Type:** INDEX
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### table

**Type:** COMMENT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### all

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### COLUMN

**Type:** COMMENT
**Status:** EXTRA
**Completeness:** 0.0%
**Accuracy:** 0.0%

### ALL

**Type:** GRANT
**Status:** EXTRA
**Completeness:** 0.0%
**Accuracy:** 0.0%

### IF

**Type:** INDEX
**Status:** EXTRA
**Completeness:** 0.0%
**Accuracy:** 0.0%

### column

**Type:** COMMENT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### TABLE

**Type:** COMMENT
**Status:** EXTRA
**Completeness:** 0.0%
**Accuracy:** 0.0%

