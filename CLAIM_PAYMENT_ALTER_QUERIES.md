# CLAIM_PAYMENT TABLE ALTER QUERIES

## **Required ALTER Queries for Production Deployment**

### **1. Update Status Constraint**
```sql
-- Fix status constraint to include taken back statuses
ALTER TABLE claims.claim_payment 
DROP CONSTRAINT IF EXISTS ck_claim_payment_status;

ALTER TABLE claims.claim_payment 
ADD CONSTRAINT ck_claim_payment_status CHECK (
  payment_status IN ('FULLY_PAID', 'PARTIALLY_PAID', 'REJECTED', 'PENDING', 'TAKEN_BACK', 'PARTIALLY_TAKEN_BACK')
);
```

### **2. Update Amounts Constraint**
```sql
-- Fix amounts constraint to include taken back columns
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
```

### **3. Update Activities Constraint**
```sql
-- Fix activities constraint to include taken back activities
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

### **4. Add Performance Indexes**
```sql
-- Add indexes for taken back support
CREATE INDEX IF NOT EXISTS idx_claim_payment_taken_back_amount ON claims.claim_payment(total_taken_back_amount);
CREATE INDEX IF NOT EXISTS idx_claim_payment_net_paid_amount ON claims.claim_payment(total_net_paid_amount);
CREATE INDEX IF NOT EXISTS idx_claim_payment_taken_back_status ON claims.claim_payment(payment_status) 
  WHERE payment_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK');
CREATE INDEX IF NOT EXISTS idx_claim_payment_taken_back_activities ON claims.claim_payment(taken_back_activities, partially_taken_back_activities);
CREATE INDEX IF NOT EXISTS idx_claim_payment_financial_summary ON claims.claim_payment(total_submitted_amount, total_net_paid_amount, total_taken_back_amount);
```

### **5. Add Column Comments**
```sql
-- Add comments for taken back columns
COMMENT ON COLUMN claims.claim_payment.total_taken_back_amount IS 'Total amount taken back (reversed) across all activities';
COMMENT ON COLUMN claims.claim_payment.total_taken_back_count IS 'Total number of taken back transactions';
COMMENT ON COLUMN claims.claim_payment.total_net_paid_amount IS 'Net amount paid after accounting for taken back amounts (paid - taken_back)';
COMMENT ON COLUMN claims.claim_payment.taken_back_activities IS 'Number of activities with TAKEN_BACK status';
COMMENT ON COLUMN claims.claim_payment.partially_taken_back_activities IS 'Number of activities with PARTIALLY_TAKEN_BACK status';
```

## **Execution Order**
1. Run constraint updates first (1-3)
2. Add indexes (4)
3. Add comments (5)

## **Rollback Queries (If Needed)**
```sql
-- Rollback constraints to original state
ALTER TABLE claims.claim_payment 
DROP CONSTRAINT IF EXISTS ck_claim_payment_status;

ALTER TABLE claims.claim_payment 
ADD CONSTRAINT ck_claim_payment_status CHECK (
  payment_status IN ('FULLY_PAID', 'PARTIALLY_PAID', 'REJECTED', 'PENDING')
);

-- Drop new indexes
DROP INDEX IF EXISTS idx_claim_payment_taken_back_amount;
DROP INDEX IF EXISTS idx_claim_payment_net_paid_amount;
DROP INDEX IF EXISTS idx_claim_payment_taken_back_status;
DROP INDEX IF EXISTS idx_claim_payment_taken_back_activities;
DROP INDEX IF EXISTS idx_claim_payment_financial_summary;
```
