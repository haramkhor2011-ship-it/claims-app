-- Setup toggles for 300-day backfill processing
-- This script configures the system to run the backfill at startup instead of scheduled polling

-- Disable scheduled polling to prevent interference
UPDATE claims.integration_toggle SET enabled = false WHERE code = 'dhpo.new.enabled';
UPDATE claims.integration_toggle SET enabled = false WHERE code = 'dhpo.search.enabled';

-- Enable startup backfill (runs once at application startup)
INSERT INTO claims.integration_toggle(code, enabled, description) 
VALUES ('dhpo.startup.backfill.enabled', true, 'Run 300-day backfill at application startup')
ON CONFLICT(code) DO UPDATE SET enabled = true, updated_at = now();

-- Verify the toggles
SELECT code, enabled, description FROM claims.integration_toggle 
WHERE code IN ('dhpo.new.enabled', 'dhpo.search.enabled', 'dhpo.startup.backfill.enabled')
ORDER BY code;
