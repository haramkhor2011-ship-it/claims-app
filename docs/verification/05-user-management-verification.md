# User Management Verification

**Generated:** 2025-10-25 18:57:19

## Summary

- **Source Files:** ../src/main/resources/db/user_management_schema.sql
- **Docker File:** ../docker/db-init/05-user-management.sql
- **Total Objects Expected:** 12
- **Total Objects Found:** 12
- **Completeness:** 100.0%
- **Overall Accuracy:** 96.5%

## Objects Overview

| Object Name | Type | Status | Completeness | Accuracy | Notes |
|-------------|------|--------|--------------|----------|-------|
| update_sso_providers_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| claims.user_facilities | GRANT | ✓ | 100.0% | 100.0% | Perfect match |
| IF | INDEX | ✓ | 100.0% | 100.0% | Perfect match |
| claims.user_sso_mappings | GRANT | ✓ | 100.0% | 100.0% | Perfect match |
| claims.reports_metadata | GRANT | ✓ | 100.0% | 100.0% | Perfect match |
| claims.refresh_tokens | GRANT | ✓ | 100.0% | 100.0% | Perfect match |
| claims.user_roles | GRANT | ✓ | 100.0% | 100.0% | Perfect match |
| COLUMN | COMMENT | ✓ | 100.0% | 57.4% | Perfect match |
| claims.user_report_permissions | GRANT | ✓ | 100.0% | 100.0% | Perfect match |
| update_user_sso_mappings_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| update_reports_metadata_updated_at | TRIGGER | ✓ | 100.0% | 100.0% | Perfect match |
| TABLE | COMMENT | ✓ | 100.0% | 100.0% | Perfect match |

## Detailed Comparisons

