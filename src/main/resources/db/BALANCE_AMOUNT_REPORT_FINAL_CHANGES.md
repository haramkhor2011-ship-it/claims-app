# Balance Amount to be Received Report - Final Implementation Changes

## 📋 Summary

Based on the analysis of the report requirements (`reports/txt_reports/Balance Amount to be Received.txt`) and the JSON mapping configuration (`src/main/resources/json/report_columns_xml_mappings.json`), the following corrections have been applied to make the implementation final and production-ready.

## ✅ Key Corrections Applied

### 1. **FacilityGroupID Mapping** 
- **Before**: Used `provider_name`
- **After**: Use `claims.encounter.facility_id` (preferred) or `claims.claim.provider_id`
- **JSON Mapping**: `"Best Path": "claims.encounter.facility_id (preferred) or claims.claim.provider_id for submission"`

### 2. **HealthAuthority Mapping**
- **Before**: Used `provider_name`
- **After**: Use `claims.ingestion_file.sender_id` for submission, `receiver_id` for remittance
- **JSON Mapping**: `"Best Path": "claims.ingestion_file.sender_id for submission; claims.ingestion_file.receiver_id for remittance"`

### 3. **Receiver_Name Mapping**
- **Before**: Used `payer_name`
- **After**: Use `claims_ref.payer.name` joined on `payer_code = ingestion_file.receiver_id`
- **JSON Mapping**: `"Best Path": "claims_ref.payer.name joined on payer_code = ingestion_file.receiver_id"`

### 4. **Column Naming Updates** (Per Report Suggestions)
- `ClaimAmt` → `Billed Amount`
- `RemittedAmt` → `Amount Received`
- `WriteOffAmt` → `Write-off Amount`
- `RejectedAmt` → `Denied Amount`
- `PendingAmt` → `Outstanding Balance`
- `ClaimSubmissionDate` → `Submission Date`
- `LastSubmissionFile` → `Submission Reference File`

### 5. **Database Structure Corrections**
- Added proper joins to `claims.ingestion_file` for submission and remittance data
- Added health authority fields from ingestion file headers
- Corrected facility group mapping to use encounter facility_id

### 6. **Field Mappings Verified Against JSON**
- **ClaimNumber**: `claims.claim_key.claim_id` ✅
- **EncounterStartDate**: `claims.encounter.start_at` ✅
- **EncounterEndDate**: `claims.encounter.end_at` ✅
- **IDPayer**: `claims.claim.id_payer` ✅
- **MemberID**: `claims.claim.member_id` ✅
- **EmiratesIDNumber**: `claims.claim.emirates_id_number` ✅
- **BilledAmount**: `sum(claims.activity.net)` ✅
- **PaidAmount**: `claims.remittance_activity.payment_amount` ✅
- **OutstandingBalance**: `claims.claim.net - sum(claims.remittance_activity.payment_amount)` ✅

## 📊 Report Structure Compliance

### Tab A: Balance Amount to be received
- ✅ All required columns present
- ✅ Proper field mappings per JSON
- ✅ Column naming follows report suggestions
- ✅ Detailed sub-data expandable

### Tab B: Initial Not Remitted Balance
- ✅ All required columns present
- ✅ ReceiverID and Receiver_Name properly mapped
- ✅ Aging bucket support added
- ✅ Proper filtering for initial pending claims

### Tab C: After Resubmission Not Remitted Balance
- ✅ All required columns present
- ✅ Resubmission details included
- ✅ Proper filtering for resubmitted claims
- ✅ Pending amount tracking

## 🔧 Technical Improvements

### 1. **Performance Optimizations**
- Proper indexing on key fields
- Efficient lateral joins for aggregations
- Optimized WHERE clauses for filtering

### 2. **Data Integrity**
- Proper NULL handling with COALESCE
- Consistent data type mappings
- Referential integrity maintained

### 3. **Security**
- Row-level security with facility access control
- Parameterized queries in API functions
- Proper grants and permissions

## 📈 Additional Metrics Support

The implementation now supports the suggested additional metrics:
- **Net Collection Rate**: `Amount Received / Billed Amount`
- **Outstanding %**: `Outstanding Balance / Billed Amount`
- **Aging Analysis**: By outstanding balance buckets (0-30, 31-60, 61-90, 90+ days)
- **Write-off Ratio**: `Write-off Amount / Billed Amount`
- **Rejection Rate**: `Denied Amount / Billed Amount`

## 🚀 Production Readiness

### ✅ **Ready for Production**
- All field mappings verified against JSON configuration
- Report structure matches requirements exactly
- Column naming follows user suggestions
- Performance optimizations in place
- Security measures implemented
- Comprehensive error handling

### 📋 **Usage Examples**
```sql
-- Get all claims with outstanding balance > 1000
SELECT 
  claim_number,
  facility_name,
  facility_group_id,
  billed_amount,
  outstanding_balance,
  aging_days,
  aging_bucket
FROM claims.v_balance_amount_tab_a_corrected 
WHERE outstanding_balance > 1000 
ORDER BY aging_days DESC;

-- Monthly summary by facility
SELECT 
  facility_id,
  facility_name,
  encounter_start_year,
  encounter_start_month,
  aging_bucket,
  COUNT(*) as claim_count,
  SUM(billed_amount) as total_billed_amount,
  SUM(outstanding_balance) as total_outstanding_balance
FROM claims.v_balance_amount_tab_a_corrected
WHERE encounter_start >= '2024-01-01'
GROUP BY facility_id, facility_name, encounter_start_year, encounter_start_month, aging_bucket
ORDER BY encounter_start_year DESC, encounter_start_month DESC;
```

## 🎯 **Final Status: PRODUCTION READY**

The Balance Amount to be Received report implementation is now:
- ✅ Fully compliant with report requirements
- ✅ Properly mapped according to JSON configuration
- ✅ Using correct database schema (unified DDL)
- ✅ Following user-suggested column naming
- ✅ Optimized for performance
- ✅ Secure and production-ready

**Ready for immediate deployment and use!**
