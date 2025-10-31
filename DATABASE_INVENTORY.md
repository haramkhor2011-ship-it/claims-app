# Database Inventory Report
Generated: 2025-10-29

## Summary Statistics

- **Tables**: 63 (52 in `claims` schema, 11 in `claims_ref` schema)
- **Views**: 23 (21 in `claims` schema, 2 in `public` schema)
- **Materialized Views**: 11 (all in `claims` schema)
- **Functions**: 19 (all in `claims` schema, using PL/pgSQL)

## Tables by Schema

### `claims` Schema (52 tables)

| Table Name | Row Count | Size | Description |
|------------|-----------|------|-------------|
| activity | 0 | 80 kB | Activity codes for claims |
| claim | 0 | 120 kB | Main claims table |
| claim_activity_summary | 0 | 56 kB | Summary of claim activities |
| claim_attachment | 0 | 40 kB | Attachments for claims |
| claim_contract | 0 | 24 kB | Contract information |
| claim_event | 0 | 64 kB | Claim event history |
| claim_event_activity | 0 | 48 kB | Activities per event |
| claim_financial_timeline | 0 | 48 kB | Financial timeline |
| claim_key | 0 | 32 kB | Claim key references |
| claim_payment | 0 | 136 kB | Payment information |
| claim_resubmission | 0 | 32 kB | Resubmission tracking |
| claim_status_timeline | 0 | 32 kB | Status changes |
| code_discovery_audit | 0 | 40 kB | Code discovery audit |
| diagnosis | 0 | 64 kB | Diagnosis codes |
| encounter | 0 | 56 kB | Encounter information |
| event_observation | 0 | 40 kB | Event observations |
| facility_dhpo_config | 0 | 32 kB | DHPO configuration |
| ingestion_error | 0 | 48 kB | Ingestion errors |
| ingestion_file | 0 | 56 kB | Ingestion files |
| ingestion_file_audit | 0 | 72 kB | File audit trail |
| ingestion_run | **345** | 136 kB | Ingestion runs |
| integration_toggle | **4** | 64 kB | Feature toggles |
| mv_balance_amount_summary | 0 | 40 kB | Balance amount MV |
| mv_claim_details_complete | 0 | 32 kB | Complete claim details MV |
| mv_claim_summary_encounterwise | 0 | 8 kB | Encounter-wise summary MV |
| mv_claim_summary_payerwise | 0 | 8 kB | Payer-wise summary MV |
| mv_claims_monthly_agg | 0 | 32 kB | Monthly aggregation MV |
| mv_doctor_denial_summary | 0 | 32 kB | Doctor denial summary MV |
| mv_rejected_claims_summary | 0 | 32 kB | Rejected claims MV |
| mv_remittance_advice_summary | 0 | 40 kB | Remittance advice MV |
| mv_remittances_resubmission_activity_level | 0 | 32 kB | Resubmission activity MV |
| mv_remittances_resubmission_claim_level | 0 | 8 kB | Resubmission claim MV |
| mv_resubmission_cycles | 0 | 32 kB | Resubmission cycles MV |
| observation | 0 | 48 kB | Observations |
| payer_performance_summary | 0 | 40 kB | Payer performance |
| refresh_tokens | 0 | 40 kB | JWT refresh tokens |
| remittance | 0 | 24 kB | Remittances |
| remittance_activity | 0 | 88 kB | Remittance activities |
| remittance_claim | 0 | 104 kB | Remittance claims |
| reports_metadata | **7** | 96 kB | Report metadata |
| security_audit_log | 0 | 48 kB | Security audit |
| sso_providers | 0 | 24 kB | SSO providers |
| submission | 0 | 24 kB | Submissions |
| user_facilities | 0 | 40 kB | User-facility mappings |
| user_report_permissions | 0 | 32 kB | Report permissions |
| user_roles | **1** | 72 kB | User roles |
| user_sso_mappings | 0 | 40 kB | SSO mappings |
| users | **1** | 120 kB | Users |
| verification_result | 0 | 32 kB | Verification results |
| verification_rule | 0 | 40 kB | Verification rules |
| verification_run | 0 | 24 kB | Verification runs |

### `claims_ref` Schema (11 tables)

| Table Name | Row Count | Size | Description |
|------------|-----------|------|-------------|
| activity_code | 0 | 64 kB | Activity code reference |
| bootstrap_status | 0 | 40 kB | Bootstrap status |
| clinician | 0 | 136 kB | Clinician reference |
| denial_code | 0 | 48 kB | Denial code reference |
| diagnosis_code | 0 | 64 kB | Diagnosis code reference |
| encounter_type | **10** | 64 kB | Encounter types |
| facility | 0 | 9.5 MB | Facility reference (largest table) |
| observation_code | 0 | 24 kB | Observation code reference |
| observation_type | **8** | 64 kB | Observation types |
| payer | 0 | 264 kB | Payer reference |
| provider | 0 | 9.5 MB | Provider reference (largest table) |
| resubmission_type | 0 | 16 kB | Resubmission types |

## Views (23 total)

### `claims` Schema (21 views)

1. `v_after_resubmission_not_remitted_balance`
2. `v_balance_amount_to_be_received`
3. `v_balance_amount_to_be_received_base`
4. `v_claim_details_with_activity`
5. `v_claim_summary_encounterwise`
6. `v_claim_summary_monthwise`
7. `v_claim_summary_payerwise`
8. `v_doctor_denial_detail`
9. `v_doctor_denial_high_denial`
10. `v_doctor_denial_summary`
11. `v_initial_not_remitted_balance`
12. `v_rejected_claims_base`
13. `v_rejected_claims_claim_wise`
14. `v_rejected_claims_receiver_payer`
15. `v_rejected_claims_summary`
16. `v_rejected_claims_summary_by_year`
17. `v_remittance_advice_activity_wise`
18. `v_remittance_advice_claim_wise`
19. `v_remittance_advice_header`
20. `v_remittances_resubmission_activity_level`
21. `v_remittances_resubmission_claim_level`

### `public` Schema (2 views)

1. `pg_stat_statements` - PostgreSQL statistics
2. `pg_stat_statements_info` - Statistics info

## Materialized Views (11 total)

All in `claims` schema:

| MV Name | Row Count | Size |
|---------|-----------|------|
| mv_balance_amount_summary | 0 | 40 kB |
| mv_claim_details_complete | 0 | 32 kB |
| mv_claim_summary_encounterwise | 0 | 8 kB |
| mv_claim_summary_payerwise | 0 | 8 kB |
| mv_claims_monthly_agg | 0 | 32 kB |
| mv_doctor_denial_summary | 0 | 32 kB |
| mv_rejected_claims_summary | 0 | 32 kB |
| mv_remittance_advice_summary | 0 | 40 kB |
| mv_remittances_resubmission_activity_level | 0 | 32 kB |
| mv_remittances_resubmission_claim_level | 0 | 8 kB |
| mv_resubmission_cycles | 0 | 32 kB |

## Functions (19 total)

All in `claims` schema, using PL/pgSQL:

### Reporting Functions

1. **`get_balance_amount_summary`** - Returns balance amount summary table
   - Parameters: `p_facility_id`, `p_payer_id`, `p_start_date`, `p_end_date`
   
2. **`get_claim_summary_monthwise`** - Returns monthly claim summary
   - Parameters: `p_facility_id`, `p_payer_id`, `p_start_month`, `p_end_month`
   
3. **`get_rejected_claims_summary`** - Returns rejected claims summary
   - Parameters: `p_facility_id`, `p_payer_id`, `p_start_date`, `p_end_date`

### Payment Functions

4. **`get_claim_payment_status`** - Returns payment status for a claim
   - Parameter: `p_claim_key_id`
   
5. **`get_claim_total_paid`** - Returns total paid amount
   - Parameter: `p_claim_key_id`
   
6. **`is_claim_fully_paid`** - Checks if claim is fully paid
   - Parameter: `p_claim_key_id`

### Calculation/Update Functions

7. **`recalculate_activity_summary`** - Recalculates activity summary
   - Parameter: `p_claim_key_id`
   
8. **`recalculate_all_claim_payments`** - Recalculates all claim payments
   - Parameters: None
   
9. **`recalculate_claim_payment`** - Recalculates single claim payment
   - Parameter: `p_claim_key_id`
   
10. **`recalculate_claim_payments_by_date`** - Recalculates by date range
    - Parameters: `p_start_date`, `p_end_date`
    
11. **`update_activity_summary_on_remittance_activity`** - Updates activity summary
    - Parameter: `p_activity_id`
    
12. **`update_financial_timeline_on_event`** - Updates financial timeline
    - Parameters: `p_claim_key_id`, `p_event_type`, `p_event_date`
    
13. **`update_payer_performance_summary`** - Updates payer performance
    - Parameter: `p_claim_key_id`

### Trigger Functions

14. **`trigger_update_activity_summary`** - Trigger for activity summary
15. **`update_claim_payment_on_remittance`** - Trigger for remittance updates
16. **`update_claim_payment_on_remittance_activity`** - Trigger for remittance activity
17. **`update_updated_at_column`** - Generic updated_at trigger

### Utility Functions

18. **`map_status_to_text`** - Maps status code to text
    - Parameter: `p_status`
    
19. **`validate_claim_payment_integrity`** - Validates payment integrity
    - Parameter: `p_claim_key_id`

## Quick Query Commands

### List all tables
```bash
Get-Content query_tables.sql | docker exec -i claims-postgres psql -U claims_user -d claims
```

### List all views
```bash
Get-Content query_views.sql | docker exec -i claims-postgres psql -U claims_user -d claims
```

### List materialized views
```bash
Get-Content query_materialized_views.sql | docker exec -i claims-postgres psql -U claims_user -d claims
```

### List functions
```bash
Get-Content query_functions.sql | docker exec -i claims-postgres psql -U claims_user -d claims
```

### Interactive psql session
```bash
docker exec -it claims-postgres psql -U claims_user -d claims
```

## Notes

- Most tables are empty (0 rows) - database appears to be freshly initialized
- Only a few tables have data:
  - `ingestion_run`: 345 rows
  - `integration_toggle`: 4 rows
  - `reports_metadata`: 7 rows
  - `user_roles`: 1 row
  - `users`: 1 row
  - `encounter_type`: 10 rows
  - `observation_type`: 8 rows
  
- Largest tables by size:
  - `claims_ref.facility`: 9.5 MB
  - `claims_ref.provider`: 9.5 MB
  - These are reference data tables with indexes

- All materialized views are empty and may need refreshing if used in production







