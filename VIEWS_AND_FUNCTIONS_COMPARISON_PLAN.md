# Views and Functions Comparison Plan

## Objective
Systematically compare all SQL views (v_*) and functions from individual report SQL files in `src/main/resources/db/reports_sql/` with their consolidated versions in `docker/db-init/06-report-views.sql` and `08-functions-procedures.sql`.

## Scope
- **21 Views** from individual report files
- **15+ Functions** from individual report files
- Compare with consolidated files in Docker init

## Approach
1. Extract view definitions from individual files
2. Extract view definitions from consolidated file
3. Extract function definitions from individual files
4. Extract function definitions from consolidated file
5. Compare definitions line-by-line
6. Document differences

## Expected Deliverables
A comprehensive comparison report showing:
- Exact matches
- Differences in definitions
- Missing views/functions
- Column differences
- CTE differences
- GROUP BY differences
- ORDER BY differences
- claim_activity_summary usage differences


