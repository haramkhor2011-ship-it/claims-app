# CLAIM_PAYMENT TABLE - ADD MISSING COLUMNS ALTER QUERIES

## **Required ALTER Queries to Add Taken Back Columns**

### **1. Add Financial Columns**
```sql
-- Add taken back financial columns
ALTER TABLE claims.claim_payment 
ADD COLUMN IF NOT EXISTS total_taken_back_amount NUMERIC(15,2) NOT NULL DEFAULT 0;

ALTER TABLE claims.claim_payment 
ADD COLUMN IF NOT EXISTS total_taken_back_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE claims.claim_payment 
ADD COLUMN IF NOT EXISTS total_net_paid_amount NUMERIC(15,2) NOT NULL DEFAULT 0;
```

### **2. Add Activity Count Columns**
```sql
-- Add taken back activity count columns
ALTER TABLE claims.claim_payment 
ADD COLUMN IF NOT EXISTS taken_back_activities INTEGER NOT NULL DEFAULT 0;

ALTER TABLE claims.claim_payment 
ADD COLUMN IF NOT EXISTS partially_taken_back_activities INTEGER NOT NULL DEFAULT 0;
```

### **3. Add Column Comments**
```sql
-- Add comments for the new columns
COMMENT ON COLUMN claims.claim_payment.total_taken_back_amount IS 'Total amount taken back (reversed) across all activities';
COMMENT ON COLUMN claims.claim_payment.total_taken_back_count IS 'Total number of taken back transactions';
COMMENT ON COLUMN claims.claim_payment.total_net_paid_amount IS 'Net amount paid after accounting for taken back amounts (paid - taken_back)';
COMMENT ON COLUMN claims.claim_payment.taken_back_activities IS 'Number of activities with TAKEN_BACK status';
COMMENT ON COLUMN claims.claim_payment.partially_taken_back_activities IS 'Number of activities with PARTIALLY_TAKEN_BACK status';
```

### **4. Update Constraints**
```sql
-- Update status constraint to include taken back statuses
ALTER TABLE claims.claim_payment 
DROP CONSTRAINT IF EXISTS ck_claim_payment_status;

ALTER TABLE claims.claim_payment 
ADD CONSTRAINT ck_claim_payment_status CHECK (
  payment_status IN ('FULLY_PAID', 'PARTIALLY_PAID', 'REJECTED', 'PENDING', 'TAKEN_BACK', 'PARTIALLY_TAKEN_BACK')
);

-- Update amounts constraint to include taken back columns
ALTER TABLE claims.claim_payment 
DROP CONSTRAINT IF EXISTS ck_claim_payment_amounts;

ALTER TABLE claims.claim_payment 
ADD CONSTRAINT ck_claim_payment_amounts CHECK (
  total_paid_amount >= 0 AND 
  total_remitted_amount >= 0 AND 
  total_rejected_amount >= 0 AND
  total_denied_amount >= 0 AND
  total_submitted_amount >= 0 AND
  total_taken_back_amount >= 0 AND
  total_taken_back_count >= 0 AND
  total_net_paid_amount >= 0
);

-- Update activities constraint to include taken back activities
ALTER TABLE claims.claim_payment 
DROP CONSTRAINT IF EXISTS ck_claim_payment_activities;

ALTER TABLE claims.claim_payment 
ADD CONSTRAINT ck_claim_payment_activities CHECK (
  total_activities >= 0 AND
  paid_activities >= 0 AND
  partially_paid_activities >= 0 AND
  rejected_activities >= 0 AND
  pending_activities >= 0 AND
  taken_back_activities >= 0 AND
  partially_taken_back_activities >= 0 AND
  (paid_activities + partially_paid_activities + rejected_activities + 
   pending_activities + taken_back_activities + partially_taken_back_activities) = total_activities
);
```

### **5. Add Performance Indexes**
```sql
-- Add indexes for taken back support
CREATE INDEX IF NOT EXISTS idx_claim_payment_taken_back_amount ON claims.claim_payment(total_taken_back_amount);
CREATE INDEX IF NOT EXISTS idx_claim_payment_net_paid_amount ON claims.claim_payment(total_net_paid_amount);
CREATE INDEX IF NOT EXISTS idx_claim_payment_taken_back_status ON claims.claim_payment(payment_status) 
  WHERE payment_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK');
CREATE INDEX IF NOT EXISTS idx_claim_payment_taken_back_activities ON claims.claim_payment(taken_back_activities, partially_taken_back_activities);
CREATE INDEX IF NOT EXISTS idx_claim_payment_financial_summary ON claims.claim_payment(total_submitted_amount, total_net_paid_amount, total_taken_back_amount);
```

## **Execution Order**
1. **Run Step 1**: Add financial columns
2. **Run Step 2**: Add activity count columns  
3. **Run Step 3**: Add column comments
4. **Run Step 4**: Update constraints
5. **Run Step 5**: Add performance indexes

## **Verification Query**
```sql
-- Verify columns were added successfully
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'claim_payment' 
  AND column_name LIKE '%taken_back%'
ORDER BY column_name;
```

## **Rollback Queries (If Needed)**
```sql
-- Remove the added columns (if rollback needed)
ALTER TABLE claims.claim_payment DROP COLUMN IF EXISTS total_taken_back_amount;
ALTER TABLE claims.claim_payment DROP COLUMN IF EXISTS total_taken_back_count;
ALTER TABLE claims.claim_payment DROP COLUMN IF EXISTS total_net_paid_amount;
ALTER TABLE claims.claim_payment DROP COLUMN IF EXISTS taken_back_activities;
ALTER TABLE claims.claim_payment DROP COLUMN IF EXISTS partially_taken_back_activities;

-- Drop the new indexes
DROP INDEX IF EXISTS idx_claim_payment_taken_back_amount;
DROP INDEX IF EXISTS idx_claim_payment_net_paid_amount;
DROP INDEX IF EXISTS idx_claim_payment_taken_back_status;
DROP INDEX IF EXISTS idx_claim_payment_taken_back_activities;
DROP INDEX IF EXISTS idx_claim_payment_financial_summary;
```

