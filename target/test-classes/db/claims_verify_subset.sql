-- 1) Required tables exist (expected: 0 rows)
WITH required(name) AS (
    VALUES
        ('claims.ingestion_file'),
        ('claims.submission'),
        ('claims.claim'),
        ('claims.activity'),
        ('claims.observation'),
        ('claims.remittance'),
        ('claims.remittance_claim'),
        ('claims.remittance_activity'),
        ('claims.claim_event'),
        ('claims.claim_status_timeline')
)
SELECT r.name AS missing_table
FROM required r
         LEFT JOIN pg_class c
                   ON c.relname = split_part(r.name, '.', 2)
         LEFT JOIN pg_namespace n
                   ON n.oid = c.relnamespace AND n.nspname = split_part(r.name, '.', 1)
WHERE c.oid IS NULL;
-- SPLIT
-- 2) ingestion_file.file_id duplicate check (expected 0 rows)
SELECT file_id, COUNT(*) c
FROM claims.ingestion_file
GROUP BY 1 HAVING COUNT(*) > 1;
