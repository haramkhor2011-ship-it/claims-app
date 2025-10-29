# SQL Verification Checklist

Use this checklist to manually verify critical SQL objects.

## General Verification Checklist

- [ ] All source files have been parsed successfully
- [ ] All Docker files have been parsed successfully
- [ ] No critical objects are missing from Docker files
- [ ] No unexpected objects exist in Docker files
- [ ] All differences have been reviewed and documented
- [ ] All intentional differences have been justified

## VIEW Verification Checklist

### For each VIEW:
- [ ] Object name matches exactly
- [ ] Object type is correct
- [ ] All columns are present and in correct order
- [ ] All CTEs/subqueries are present
- [ ] All JOINs are correct (type, tables, conditions)
- [ ] WHERE clause is complete and accurate
- [ ] GROUP BY clause matches
- [ ] ORDER BY clause matches
- [ ] All comments are preserved
- [ ] GRANT statements are present (if applicable)
- [ ] Sign-off: [ ] Verified by: ___________ Date: ___________

## MATERIALIZED_VIEW Verification Checklist

### For each MATERIALIZED_VIEW:
- [ ] Object name matches exactly
- [ ] Object type is correct
- [ ] All columns are present and in correct order
- [ ] All CTEs/subqueries are present
- [ ] All JOINs are correct (type, tables, conditions)
- [ ] WHERE clause is complete and accurate
- [ ] GROUP BY clause matches
- [ ] ORDER BY clause matches
- [ ] All comments are preserved
- [ ] GRANT statements are present (if applicable)
- [ ] Sign-off: [ ] Verified by: ___________ Date: ___________

## FUNCTION Verification Checklist

### For each FUNCTION:
- [ ] Object name matches exactly
- [ ] Object type is correct
- [ ] Function parameters match exactly
- [ ] Return type matches
- [ ] Function body/logic is identical
- [ ] All comments are preserved
- [ ] GRANT statements are present (if applicable)
- [ ] Sign-off: [ ] Verified by: ___________ Date: ___________

## TABLE Verification Checklist

### For each TABLE:
- [ ] Object name matches exactly
- [ ] Object type is correct
- [ ] All columns are present
- [ ] Column data types match
- [ ] All constraints are present
- [ ] All indexes are present
- [ ] All triggers are present
- [ ] All comments are preserved
- [ ] GRANT statements are present (if applicable)
- [ ] Sign-off: [ ] Verified by: ___________ Date: ___________

## INDEX Verification Checklist

### For each INDEX:
- [ ] Object name matches exactly
- [ ] Object type is correct
- [ ] Index name matches
- [ ] Index type (UNIQUE, etc.) matches
- [ ] Indexed columns match
- [ ] Index options match
- [ ] GRANT statements are present (if applicable)
- [ ] Sign-off: [ ] Verified by: ___________ Date: ___________

## TRIGGER Verification Checklist

### For each TRIGGER:
- [ ] Object name matches exactly
- [ ] Object type is correct
- [ ] Trigger name matches
- [ ] Trigger timing matches
- [ ] Trigger events match
- [ ] Trigger function matches
- [ ] GRANT statements are present (if applicable)
- [ ] Sign-off: [ ] Verified by: ___________ Date: ___________

## GRANT Verification Checklist

### For each GRANT:
- [ ] Object name matches exactly
- [ ] Object type is correct
- [ ] Privileges match
- [ ] Target object matches
- [ ] Grantee matches
- [ ] GRANT statements are present (if applicable)
- [ ] Sign-off: [ ] Verified by: ___________ Date: ___________

