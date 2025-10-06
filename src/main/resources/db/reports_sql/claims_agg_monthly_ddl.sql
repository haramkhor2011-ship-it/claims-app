-- ==========================================================================================================
-- CLAIMS MONTHLY AGGREGATES - DDL AND REFRESH FUNCTION (READ-OPTIMIZED SUMMARY TABLES)
-- ==========================================================================================================
--
-- Purpose
-- - Persist month-bucketed aggregates to accelerate summary tabs for Claim Summary, Rejected Claims,
--   and Doctor Denial reports while keeping drill-downs on live views.
--
-- Design
-- - Schema: claims_agg
-- - Tables: monthly_claim_summary, monthly_rejected_summary, monthly_doctor_denial
-- - Refresh: claims_agg.refresh_months(p_from, p_to) deletes and rebuilds affected month buckets
-- - Bucket rule: month_bucket := date_trunc('month', coalesce(rc.date_settlement, c.tx_at))
-- - Dimensions use reference IDs (facility_ref_id, payer_ref_id, clinician_ref_id) for label stability
--
-- Notes
-- - Labels (names/codes) are joined at read time to avoid churn on label edits
-- - Aggregation formulas mirror existing report views; guard divisions against zero
-- ==========================================================================================================

CREATE SCHEMA IF NOT EXISTS claims_agg;

-- ==========================================================================================================
-- TABLE: monthly_claim_summary (Monthwise/Payerwise/Encounterwise core metrics)
-- ==========================================================================================================
CREATE TABLE IF NOT EXISTS claims_agg.monthly_claim_summary (
  month_bucket           DATE NOT NULL,
  year                   INTEGER NOT NULL,
  month                  INTEGER NOT NULL,
  facility_ref_id        BIGINT,
  payer_ref_id           BIGINT,
  encounter_type         TEXT,

  -- Count metrics
  count_claims           BIGINT NOT NULL,
  remitted_count         BIGINT NOT NULL,
  fully_paid_count       BIGINT NOT NULL,
  partially_paid_count   BIGINT NOT NULL,
  fully_rejected_count   BIGINT NOT NULL,
  rejection_count        BIGINT NOT NULL,
  taken_back_count       BIGINT NOT NULL,
  pending_remittance_count BIGINT NOT NULL,
  self_pay_count         BIGINT NOT NULL,

  -- Amount metrics
  claim_amount           NUMERIC(14,2) NOT NULL,
  initial_claim_amount   NUMERIC(14,2) NOT NULL,
  remitted_amount        NUMERIC(14,2) NOT NULL,
  remitted_net_amount    NUMERIC(14,2) NOT NULL,
  fully_paid_amount      NUMERIC(14,2) NOT NULL,
  partially_paid_amount  NUMERIC(14,2) NOT NULL,
  fully_rejected_amount  NUMERIC(14,2) NOT NULL,
  rejected_amount        NUMERIC(14,2) NOT NULL,
  pending_remittance_amount NUMERIC(14,2) NOT NULL,
  self_pay_amount        NUMERIC(14,2) NOT NULL,

  -- Percentage metrics
  rejected_percentage_on_initial   NUMERIC(5,2) NOT NULL,
  rejected_percentage_on_remittance NUMERIC(5,2) NOT NULL,
  collection_rate                  NUMERIC(5,2) NOT NULL,

  PRIMARY KEY (month_bucket, facility_ref_id, payer_ref_id, encounter_type)
);

CREATE INDEX IF NOT EXISTS idx_mc_summary_month ON claims_agg.monthly_claim_summary(month_bucket);
CREATE INDEX IF NOT EXISTS idx_mc_summary_facility ON claims_agg.monthly_claim_summary(month_bucket, facility_ref_id);
CREATE INDEX IF NOT EXISTS idx_mc_summary_payer ON claims_agg.monthly_claim_summary(month_bucket, payer_ref_id);

COMMENT ON TABLE claims_agg.monthly_claim_summary IS 'Monthly rollups for claim summary with dimensions: month, facility_ref_id, payer_ref_id, encounter_type';

-- ==========================================================================================================
-- TABLE: monthly_rejected_summary (Rejected Claims high-level metrics)
-- ==========================================================================================================
CREATE TABLE IF NOT EXISTS claims_agg.monthly_rejected_summary (
  month_bucket           DATE NOT NULL,
  year                   INTEGER NOT NULL,
  month                  INTEGER NOT NULL,
  facility_ref_id        BIGINT,
  payer_ref_id           BIGINT,

  total_claim            BIGINT NOT NULL,
  claim_amt              NUMERIC(14,2) NOT NULL,
  remitted_claim         BIGINT NOT NULL,
  remitted_amt           NUMERIC(14,2) NOT NULL,
  rejected_claim         BIGINT NOT NULL,
  rejected_amt           NUMERIC(14,2) NOT NULL,
  pending_remittance     BIGINT NOT NULL,
  pending_remittance_amt NUMERIC(14,2) NOT NULL,
  rejected_percentage_remittance NUMERIC(5,2) NOT NULL,
  rejected_percentage_submission NUMERIC(5,2) NOT NULL,

  PRIMARY KEY (month_bucket, facility_ref_id, payer_ref_id)
);

CREATE INDEX IF NOT EXISTS idx_mr_summary_month ON claims_agg.monthly_rejected_summary(month_bucket);
CREATE INDEX IF NOT EXISTS idx_mr_summary_facility ON claims_agg.monthly_rejected_summary(month_bucket, facility_ref_id);
CREATE INDEX IF NOT EXISTS idx_mr_summary_payer ON claims_agg.monthly_rejected_summary(month_bucket, payer_ref_id);

COMMENT ON TABLE claims_agg.monthly_rejected_summary IS 'Monthly rollups for rejected claims with dimensions: month, facility_ref_id, payer_ref_id';

-- ==========================================================================================================
-- TABLE: monthly_doctor_denial (Doctor Denial summary metrics)
-- ==========================================================================================================
CREATE TABLE IF NOT EXISTS claims_agg.monthly_doctor_denial (
  month_bucket           DATE NOT NULL,
  year                   INTEGER NOT NULL,
  month                  INTEGER NOT NULL,
  clinician_ref_id       BIGINT,
  facility_ref_id        BIGINT,
  payer_ref_id           BIGINT,

  total_claims           BIGINT NOT NULL,
  total_claim_amount     NUMERIC(14,2) NOT NULL,
  remitted_amount        NUMERIC(14,2) NOT NULL,
  rejected_amount        NUMERIC(14,2) NOT NULL,
  pending_remittance_amount NUMERIC(14,2) NOT NULL,
  remitted_claims        BIGINT NOT NULL,
  rejected_claims        BIGINT NOT NULL,
  pending_remittance_claims BIGINT NOT NULL,

  rejection_percentage   NUMERIC(5,2) NOT NULL,
  collection_rate        NUMERIC(5,2) NOT NULL,
  avg_claim_value        NUMERIC(14,2) NOT NULL,

  PRIMARY KEY (month_bucket, clinician_ref_id, facility_ref_id)
);

CREATE INDEX IF NOT EXISTS idx_mdd_month ON claims_agg.monthly_doctor_denial(month_bucket);
CREATE INDEX IF NOT EXISTS idx_mdd_clinician ON claims_agg.monthly_doctor_denial(month_bucket, clinician_ref_id);
CREATE INDEX IF NOT EXISTS idx_mdd_facility ON claims_agg.monthly_doctor_denial(month_bucket, facility_ref_id);

COMMENT ON TABLE claims_agg.monthly_doctor_denial IS 'Monthly rollups for doctor denial with dimensions: month, clinician_ref_id, facility_ref_id';

-- ==========================================================================================================
-- REFRESH FUNCTION: claims_agg.refresh_months(p_from, p_to)
-- ==========================================================================================================
CREATE OR REPLACE FUNCTION claims_agg.refresh_months(
  p_from TIMESTAMPTZ,
  p_to   TIMESTAMPTZ
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_start DATE := DATE_TRUNC('month', p_from)::DATE;
  v_end   DATE := DATE_TRUNC('month', p_to)::DATE;
BEGIN
  IF p_from IS NULL OR p_to IS NULL THEN
    RAISE EXCEPTION 'Both p_from and p_to are required';
  END IF;
  IF p_from > p_to THEN
    RAISE EXCEPTION 'Invalid range: p_from (%) > p_to (%)', p_from, p_to;
  END IF;

  -- Compute buckets to refresh
  WITH buckets AS (
    SELECT gs::DATE AS month_bucket,
           EXTRACT(YEAR FROM gs)::INT AS year,
           EXTRACT(MONTH FROM gs)::INT AS month
    FROM GENERATE_SERIES(v_start, v_end, INTERVAL '1 month') gs
  ),
  d1 AS (
    DELETE FROM claims_agg.monthly_claim_summary m
    USING buckets b
    WHERE m.month_bucket = b.month_bucket
    RETURNING 1
  ),
  d2 AS (
    DELETE FROM claims_agg.monthly_rejected_summary r
    USING buckets b
    WHERE r.month_bucket = b.month_bucket
    RETURNING 1
  ),
  d3 AS (
    DELETE FROM claims_agg.monthly_doctor_denial d
    USING buckets b
    WHERE d.month_bucket = b.month_bucket
    RETURNING 1
  ),
  del AS (
    SELECT 1 FROM d1
    FULL JOIN d2 ON TRUE
    FULL JOIN d3 ON TRUE
  )
  -- Rebuild monthly_claim_summary
  INSERT INTO claims_agg.monthly_claim_summary (
    month_bucket, year, month,
    facility_ref_id, payer_ref_id, encounter_type,
    count_claims, remitted_count, fully_paid_count, partially_paid_count, fully_rejected_count, rejection_count,
    taken_back_count, pending_remittance_count, self_pay_count,
    claim_amount, initial_claim_amount, remitted_amount, remitted_net_amount, fully_paid_amount, partially_paid_amount,
    fully_rejected_amount, rejected_amount, pending_remittance_amount, self_pay_amount,
    rejected_percentage_on_initial, rejected_percentage_on_remittance, collection_rate
  )
  WITH buckets AS (
    SELECT gs::DATE AS month_bucket,
           EXTRACT(YEAR FROM gs)::INT AS year,
           EXTRACT(MONTH FROM gs)::INT AS month
    FROM GENERATE_SERIES(v_start, v_end, INTERVAL '1 month') gs
  ), base AS (
    SELECT
      ck.claim_id,
      c.id AS claim_db_id,
      DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))::DATE AS month_bucket,
      e.facility_ref_id,
      COALESCE(c.payer_ref_id, rc.payer_ref_id) AS payer_ref_id,
      e.type AS encounter_type,
      c.net AS claim_net,
      ra.net AS ra_net,
      ra.payment_amount,
      rc.payment_reference
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
    WHERE DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))::DATE BETWEEN v_start AND v_end
  ), dedup_claim AS (
    SELECT
      claim_db_id,
      month_bucket,
      MAX(claim_net) AS claim_net_once
    FROM base
    GROUP BY claim_db_id, month_bucket
  )
  SELECT
    b.month_bucket,
    EXTRACT(YEAR FROM b.month_bucket)::INT AS year,
    EXTRACT(MONTH FROM b.month_bucket)::INT AS month,
    e.facility_ref_id,
    e.payer_ref_id,
    COALESCE(e.encounter_type, 'Unknown') AS encounter_type,
    COUNT(DISTINCT e.claim_id) AS count_claims,
    COUNT(DISTINCT CASE WHEN e.payment_amount IS NOT NULL THEN e.claim_id END) AS remitted_count,
    COUNT(DISTINCT CASE WHEN e.payment_amount > 0 AND e.payment_amount = e.ra_net THEN e.claim_id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN e.payment_amount > 0 AND e.payment_amount < e.ra_net THEN e.claim_id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN e.payment_amount = 0 OR e.payment_amount IS NULL OR e.ra_net IS NULL AND e.payment_amount = 0 THEN e.claim_id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN e.payment_amount = 0 OR e.payment_amount IS NULL OR e.ra_net IS NULL AND e.payment_amount = 0 THEN e.claim_id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN e.payment_amount < 0 THEN e.claim_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN e.payment_amount IS NULL OR e.payment_amount = 0 THEN e.claim_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.claim_net_once IS NOT NULL AND e.payer_ref_id IS NULL AND e.payment_amount IS NULL THEN e.claim_id END) AS self_pay_count,
    -- Amounts
    (SELECT COALESCE(SUM(c2.claim_net_once), 0) FROM dedup_claim c2 WHERE c2.month_bucket = b.month_bucket) AS claim_amount,
    (SELECT COALESCE(SUM(c2.claim_net_once), 0) FROM dedup_claim c2 WHERE c2.month_bucket = b.month_bucket) AS initial_claim_amount,
    COALESCE(SUM(e.payment_amount), 0) AS remitted_amount,
    COALESCE(SUM(e.payment_amount), 0) AS remitted_net_amount,
    COALESCE(SUM(CASE WHEN e.payment_amount > 0 AND e.payment_amount = e.ra_net THEN e.payment_amount ELSE 0 END), 0) AS fully_paid_amount,
    COALESCE(SUM(CASE WHEN e.payment_amount > 0 AND e.payment_amount < e.ra_net THEN e.payment_amount ELSE 0 END), 0) AS partially_paid_amount,
    COALESCE(SUM(CASE WHEN e.payment_amount = 0 OR e.payment_amount IS NULL THEN e.ra_net ELSE 0 END), 0) AS fully_rejected_amount,
    COALESCE(SUM(CASE WHEN e.payment_amount = 0 OR e.payment_amount IS NULL THEN e.ra_net ELSE 0 END), 0) AS rejected_amount,
    COALESCE(SUM(CASE WHEN e.payment_amount IS NULL OR e.payment_amount = 0 THEN e.claim_net ELSE 0 END), 0) AS pending_remittance_amount,
    COALESCE(SUM(CASE WHEN e.payer_ref_id IS NULL THEN e.claim_net ELSE 0 END), 0) AS self_pay_amount,
    -- Percentages
    CASE WHEN COALESCE(SUM(e.claim_net), 0) > 0
         THEN ROUND((COALESCE(SUM(CASE WHEN e.payment_amount = 0 OR e.payment_amount IS NULL THEN e.ra_net ELSE 0 END), 0) / SUM(e.claim_net)) * 100, 2)
         ELSE 0 END AS rejected_percentage_on_initial,
    CASE WHEN (COALESCE(SUM(e.payment_amount), 0) + COALESCE(SUM(CASE WHEN e.payment_amount = 0 OR e.payment_amount IS NULL THEN e.ra_net ELSE 0 END), 0)) > 0
         THEN ROUND((COALESCE(SUM(CASE WHEN e.payment_amount = 0 OR e.payment_amount IS NULL THEN e.ra_net ELSE 0 END), 0)
                    /
                    (COALESCE(SUM(e.payment_amount), 0) + COALESCE(SUM(CASE WHEN e.payment_amount = 0 OR e.payment_amount IS NULL THEN e.ra_net ELSE 0 END), 0))) * 100, 2)
         ELSE 0 END AS rejected_percentage_on_remittance,
    CASE WHEN COALESCE(SUM(e.claim_net), 0) > 0
         THEN ROUND((COALESCE(SUM(e.payment_amount), 0) / SUM(e.claim_net)) * 100, 2)
         ELSE 0 END AS collection_rate
  FROM buckets b
  JOIN base e ON e.month_bucket = b.month_bucket
  LEFT JOIN dedup_claim c ON c.month_bucket = b.month_bucket AND c.claim_db_id = e.claim_db_id
  GROUP BY b.month_bucket, e.facility_ref_id, e.payer_ref_id, e.encounter_type;

  -- Rebuild monthly_rejected_summary
  INSERT INTO claims_agg.monthly_rejected_summary (
    month_bucket, year, month, facility_ref_id, payer_ref_id,
    total_claim, claim_amt, remitted_claim, remitted_amt, rejected_claim, rejected_amt,
    pending_remittance, pending_remittance_amt,
    rejected_percentage_remittance, rejected_percentage_submission
  )
  WITH buckets AS (
    SELECT gs::DATE AS month_bucket,
           EXTRACT(YEAR FROM gs)::INT AS year,
           EXTRACT(MONTH FROM gs)::INT AS month
    FROM GENERATE_SERIES(v_start, v_end, INTERVAL '1 month') gs
  ), base AS (
    SELECT
      ck.claim_id,
      c.id AS claim_db_id,
      DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))::DATE AS month_bucket,
      e.facility_ref_id,
      COALESCE(c.payer_ref_id, rc.payer_ref_id) AS payer_ref_id,
      a.net AS activity_net_amount,
      ra.payment_amount AS activity_payment_amount
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims.activity a ON a.claim_id = c.id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id AND ra.activity_id = a.activity_id
    WHERE DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))::DATE BETWEEN v_start AND v_end
  )
  SELECT
    b.month_bucket,
    EXTRACT(YEAR FROM b.month_bucket)::INT AS year,
    EXTRACT(MONTH FROM b.month_bucket)::INT AS month,
    e.facility_ref_id,
    e.payer_ref_id,
    COUNT(DISTINCT e.claim_id) AS total_claim,
    COALESCE(SUM(e.activity_net_amount), 0) AS claim_amt,
    COUNT(DISTINCT CASE WHEN e.activity_payment_amount IS NOT NULL THEN e.claim_id END) AS remitted_claim,
    COALESCE(SUM(COALESCE(e.activity_payment_amount, 0)), 0) AS remitted_amt,
    COUNT(DISTINCT CASE WHEN COALESCE(e.activity_payment_amount, 0) = 0 THEN e.claim_id END) AS rejected_claim,
    COALESCE(SUM(CASE WHEN COALESCE(e.activity_payment_amount, 0) = 0 THEN e.activity_net_amount ELSE 0 END), 0) AS rejected_amt,
    COUNT(DISTINCT CASE WHEN COALESCE(e.activity_payment_amount, 0) = 0 THEN e.claim_id END) AS pending_remittance,
    COALESCE(SUM(CASE WHEN COALESCE(e.activity_payment_amount, 0) = 0 THEN e.activity_net_amount ELSE 0 END), 0) AS pending_remittance_amt,
    CASE WHEN (COALESCE(SUM(COALESCE(e.activity_payment_amount, 0)), 0) + COALESCE(SUM(CASE WHEN COALESCE(e.activity_payment_amount, 0) = 0 THEN e.activity_net_amount ELSE 0 END), 0)) > 0
         THEN ROUND((COALESCE(SUM(CASE WHEN COALESCE(e.activity_payment_amount, 0) = 0 THEN e.activity_net_amount ELSE 0 END), 0)
                    /
                    (COALESCE(SUM(COALESCE(e.activity_payment_amount, 0)), 0) + COALESCE(SUM(CASE WHEN COALESCE(e.activity_payment_amount, 0) = 0 THEN e.activity_net_amount ELSE 0 END), 0))) * 100, 2)
         ELSE 0 END AS rejected_percentage_remittance,
    CASE WHEN COALESCE(SUM(e.activity_net_amount), 0) > 0
         THEN ROUND((COALESCE(SUM(CASE WHEN COALESCE(e.activity_payment_amount, 0) = 0 THEN e.activity_net_amount ELSE 0 END), 0) / SUM(e.activity_net_amount)) * 100, 2)
         ELSE 0 END AS rejected_percentage_submission
  FROM buckets b
  JOIN base e ON e.month_bucket = b.month_bucket
  GROUP BY b.month_bucket, e.facility_ref_id, e.payer_ref_id;

  -- Rebuild monthly_doctor_denial
  INSERT INTO claims_agg.monthly_doctor_denial (
    month_bucket, year, month,
    clinician_ref_id, facility_ref_id, payer_ref_id,
    total_claims, total_claim_amount, remitted_amount, rejected_amount, pending_remittance_amount,
    remitted_claims, rejected_claims, pending_remittance_claims,
    rejection_percentage, collection_rate, avg_claim_value
  )
  WITH buckets AS (
    SELECT gs::DATE AS month_bucket,
           EXTRACT(YEAR FROM gs)::INT AS year,
           EXTRACT(MONTH FROM gs)::INT AS month
    FROM GENERATE_SERIES(v_start, v_end, INTERVAL '1 month') gs
  ), base AS (
    SELECT
      DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))::DATE AS month_bucket,
      a.clinician_ref_id,
      e.facility_ref_id,
      COALESCE(c.payer_ref_id, rc.payer_ref_id) AS payer_ref_id,
      ck.claim_id,
      a.net AS activity_net,
      ra.payment_amount,
      ra.denial_code,
      rc.date_settlement
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.activity a ON a.claim_id = c.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id AND ra.activity_id = a.activity_id
    WHERE DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))::DATE BETWEEN v_start AND v_end
  )
  SELECT
    b.month_bucket,
    EXTRACT(YEAR FROM b.month_bucket)::INT AS year,
    EXTRACT(MONTH FROM b.month_bucket)::INT AS month,
    e.clinician_ref_id,
    e.facility_ref_id,
    e.payer_ref_id,
    COUNT(DISTINCT e.claim_id) AS total_claims,
    COALESCE(SUM(e.activity_net), 0) AS total_claim_amount,
    COALESCE(SUM(COALESCE(e.payment_amount, 0)), 0) AS remitted_amount,
    COALESCE(SUM(CASE WHEN e.payment_amount = 0 OR e.denial_code IS NOT NULL THEN e.activity_net ELSE 0 END), 0) AS rejected_amount,
    COALESCE(SUM(CASE WHEN e.date_settlement IS NULL THEN e.activity_net ELSE 0 END), 0) AS pending_remittance_amount,
    COUNT(DISTINCT CASE WHEN e.payment_amount IS NOT NULL THEN e.claim_id END) AS remitted_claims,
    COUNT(DISTINCT CASE WHEN e.payment_amount = 0 OR e.denial_code IS NOT NULL THEN e.claim_id END) AS rejected_claims,
    COUNT(DISTINCT CASE WHEN e.date_settlement IS NULL THEN e.claim_id END) AS pending_remittance_claims,
    CASE WHEN COUNT(DISTINCT e.claim_id) > 0
         THEN ROUND((COUNT(DISTINCT CASE WHEN e.payment_amount = 0 OR e.denial_code IS NOT NULL THEN e.claim_id END) * 100.0) / COUNT(DISTINCT e.claim_id), 2)
         ELSE 0 END AS rejection_percentage,
    CASE WHEN COALESCE(SUM(e.activity_net), 0) > 0
         THEN ROUND((COALESCE(SUM(COALESCE(e.payment_amount, 0)), 0) / SUM(e.activity_net)) * 100, 2)
         ELSE 0 END AS collection_rate,
    CASE WHEN COUNT(DISTINCT e.claim_id) > 0
         THEN ROUND(COALESCE(SUM(e.activity_net), 0) / COUNT(DISTINCT e.claim_id), 2)
         ELSE 0 END AS avg_claim_value
  FROM buckets b
  JOIN base e ON e.month_bucket = b.month_bucket
  GROUP BY b.month_bucket, e.clinician_ref_id, e.facility_ref_id, e.payer_ref_id;

END;
$$;

COMMENT ON FUNCTION claims_agg.refresh_months(timestamptz, timestamptz) IS 'Rebuilds monthly aggregates for buckets between p_from and p_to inclusive';

-- ==========================================================================================================
-- GRANTS
-- ==========================================================================================================
GRANT SELECT ON claims_agg.monthly_claim_summary TO claims_user;
GRANT SELECT ON claims_agg.monthly_rejected_summary TO claims_user;
GRANT SELECT ON claims_agg.monthly_doctor_denial TO claims_user;
GRANT EXECUTE ON FUNCTION claims_agg.refresh_months(timestamptz, timestamptz) TO claims_user;


