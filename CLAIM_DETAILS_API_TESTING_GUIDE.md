# Enhanced Claim Details API Testing Guide

## Overview
This guide provides comprehensive testing instructions for the newly enhanced claim details API endpoint `/api/report-data/claim/{claimId}` with the restructured response format.

## Prerequisites
- Java 17+
- Maven 3.6+
- PostgreSQL database with test data
- Postman or similar API testing tool
- Docker (optional, for containerized testing)

## Starting the Application

### Option 1: Docker Compose (Recommended)
```bash
# Start all services including database and application
docker-compose up -d

# Check application health
curl http://localhost:8080/actuator/health

# View application logs
docker-compose logs -f app
```

### Option 2: Local Development
```bash
# Compile the application
mvn clean compile

# Run with Spring Boot
mvn spring-boot:run -Dspring-boot.run.profiles=api

# Or run the JAR
java -jar target/claims-backend-*.jar --spring.profiles.active=api
```

## Test Data Setup

### Available Test Claims
The database contains several test claims that can be used for testing:

1. **TEST_CLAIM_001** - Basic submission with payment
2. **TEST_CLAIM_002** - Submission with partial payment and denial
3. **CLM-000051 to CLM-000060** - Additional test claims with various patterns

### Verify Test Data
```sql
-- Check available test claims
SELECT claim_id, created_at FROM claims.claim_key 
WHERE claim_id LIKE 'TEST_CLAIM_%' OR claim_id LIKE 'CLM-%'
ORDER BY created_at DESC;

-- Check claim events for a specific claim
SELECT ce.type, ce.event_time, if.file_name 
FROM claims.claim_event ce
JOIN claims.ingestion_file if ON if.id = ce.ingestion_file_id
WHERE ce.claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_001')
ORDER BY ce.event_time;
```

## API Testing Scenarios

### 1. Basic Submission Only (No Resubmissions/Remittances)

**Endpoint**: `GET /api/report-data/claim/TEST_CLAIM_001`

**Expected Response Structure**:
```json
{
  "claimId": "TEST_CLAIM_001",
  "submission": {
    "fileName": "test_submission_001.xml",
    "ingestionFileId": 123,
    "submissionDate": "2024-01-10T09:00:00Z",
    "claimInfo": {
      "claimId": "TEST_CLAIM_001",
      "payerId": "TEST_PAYER_001",
      "providerId": "TEST_FAC_001",
      "netAmount": 140.00
    },
    "encounterInfo": { /* encounter details */ },
    "diagnosisInfo": [ /* diagnoses */ ],
    "activitiesInfo": [ /* activities */ ],
    "attachments": [ /* attachments for submission */ ]
  },
  "resubmissions": [],
  "remittances": [
    {
      "fileName": "test_remittance_001.xml",
      "remittanceId": 89,
      "paymentReference": "PAY-001",
      "settlementDate": "2024-01-15T00:00:00Z",
      "denialCode": null,
      "activities": [
        {
          "activityId": "ACT001",
          "paymentAmount": 140.00,
          "denialCode": null
        }
      ],
      "attachments": []
    }
  ],
  "claimTimeline": [ /* timeline events */ ],
  "metadata": {
    "user": "test-user",
    "timestamp": "2025-01-20T10:30:45",
    "executionTimeMs": 150
  }
}
```

**Validation Points**:
- ✅ `submission` object contains original submission data
- ✅ `submission.fileName` matches ingestion file name
- ✅ `resubmissions` array is empty (no resubmissions)
- ✅ `remittances` array contains payment information
- ✅ `claimTimeline` preserved for backward compatibility
- ✅ Arrays are ordered by `event_time ASC`

### 2. Submission with Resubmissions

**Endpoint**: `GET /api/report-data/claim/{claimId}` (use a claim with resubmissions)

**Expected Response Structure**:
```json
{
  "claimId": "CLAIM_WITH_RESUBMISSIONS",
  "submission": { /* original submission */ },
  "resubmissions": [
    {
      "fileName": "resubmission_batch_002.xml",
      "ingestionFileId": 145,
      "claimEventId": 567,
      "resubmissionDate": "2024-01-20T10:00:00Z",
      "resubmissionType": "CORRECTED",
      "resubmissionComment": "Corrected diagnosis code",
      "activitiesInfo": [
        {
          "activityNumber": "ACT001",
          "activityCode": "99213",
          "netAmount": 150.00,
          "quantity": 1.0,
          "clinician": "CLIN001"
        }
      ],
      "attachments": []
    }
  ],
  "remittances": [ /* remittances */ ],
  "claimTimeline": [ /* timeline */ ],
  "metadata": { /* metadata */ }
}
```

**Validation Points**:
- ✅ `resubmissions` array contains resubmission data
- ✅ `resubmissionType` and `resubmissionComment` populated
- ✅ `activitiesInfo` in resubmissions comes from `claim_event_activity` snapshots
- ✅ Resubmissions ordered by `event_time ASC`
- ✅ File names correctly associated with each resubmission

### 3. Submission with Multiple Remittances

**Endpoint**: `GET /api/report-data/claim/{claimId}` (use a claim with multiple remittances)

**Expected Response Structure**:
```json
{
  "claimId": "CLAIM_WITH_MULTIPLE_REMITTANCES",
  "submission": { /* original submission */ },
  "resubmissions": [ /* resubmissions */ ],
  "remittances": [
    {
      "fileName": "remittance_batch_001.xml",
      "remittanceId": 89,
      "remittanceClaimId": 234,
      "remittanceDate": "2024-01-25T14:30:00Z",
      "paymentReference": "PAY-001",
      "settlementDate": "2024-01-25T00:00:00Z",
      "denialCode": null,
      "activities": [
        {
          "activityId": "ACT001",
          "paymentAmount": 100.00,
          "denialCode": null
        }
      ],
      "attachments": []
    },
    {
      "fileName": "remittance_batch_002.xml",
      "remittanceId": 90,
      "remittanceClaimId": 235,
      "remittanceDate": "2024-02-01T10:00:00Z",
      "paymentReference": "PAY-002",
      "settlementDate": "2024-02-01T00:00:00Z",
      "denialCode": "CO-4",
      "activities": [
        {
          "activityId": "ACT001",
          "paymentAmount": 40.00,
          "denialCode": "CO-4"
        }
      ],
      "attachments": []
    }
  ],
  "claimTimeline": [ /* timeline */ ],
  "metadata": { /* metadata */ }
}
```

**Validation Points**:
- ✅ Multiple remittances in array
- ✅ Each remittance has correct file name
- ✅ Payment amounts and denial codes populated
- ✅ Remittances ordered by `event_time ASC`
- ✅ Claim-level and activity-level denial codes handled correctly

### 4. Full Lifecycle (Submission + Resubmissions + Remittances)

**Endpoint**: `GET /api/report-data/claim/{claimId}` (use a claim with complete lifecycle)

**Validation Points**:
- ✅ All three sections populated: `submission`, `resubmissions`, `remittances`
- ✅ Chronological order maintained across all arrays
- ✅ File names correctly associated with each event
- ✅ Activity snapshots in resubmissions vs original activities
- ✅ Complete payment and denial information in remittances

## Postman Testing Collection

### Environment Variables
Create a Postman environment with:
- `baseUrl`: `http://localhost:8080`
- `claimId`: `TEST_CLAIM_001` (or other test claim IDs)

### Test Requests

#### 1. Basic Claim Details
```http
GET {{baseUrl}}/api/report-data/claim/{{claimId}}
Content-Type: application/json
```

#### 2. Non-existent Claim
```http
GET {{baseUrl}}/api/report-data/claim/NON_EXISTENT_CLAIM
Content-Type: application/json
```

#### 3. Invalid Claim ID Format
```http
GET {{baseUrl}}/api/report-data/claim/invalid-claim-id-format
Content-Type: application/json
```

## Automated Testing Scripts

### Test Script 1: Basic Functionality
```bash
#!/bin/bash
# test_basic_functionality.sh

BASE_URL="http://localhost:8080"
TEST_CLAIMS=("TEST_CLAIM_001" "TEST_CLAIM_002" "CLM-000051")

echo "Testing Enhanced Claim Details API..."
echo "======================================"

for claim_id in "${TEST_CLAIMS[@]}"; do
    echo "Testing claim: $claim_id"
    
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json \
        "$BASE_URL/api/report-data/claim/$claim_id")
    
    if [ "$response" = "200" ]; then
        echo "✅ Success: $claim_id"
        
        # Validate response structure
        if jq -e '.submission' /tmp/response.json > /dev/null; then
            echo "  ✅ submission object present"
        else
            echo "  ❌ submission object missing"
        fi
        
        if jq -e '.resubmissions' /tmp/response.json > /dev/null; then
            echo "  ✅ resubmissions array present"
        else
            echo "  ❌ resubmissions array missing"
        fi
        
        if jq -e '.remittances' /tmp/response.json > /dev/null; then
            echo "  ✅ remittances array present"
        else
            echo "  ❌ remittances array missing"
        fi
        
    else
        echo "❌ Failed: $claim_id (HTTP $response)"
    fi
    
    echo ""
done
```

### Test Script 2: Response Structure Validation
```bash
#!/bin/bash
# test_response_structure.sh

BASE_URL="http://localhost:8080"
CLAIM_ID="TEST_CLAIM_001"

echo "Validating Response Structure for $CLAIM_ID"
echo "============================================="

response=$(curl -s "$BASE_URL/api/report-data/claim/$CLAIM_ID")

# Check required fields
echo "Checking required fields..."

required_fields=("claimId" "submission" "resubmissions" "remittances" "claimTimeline" "metadata")
for field in "${required_fields[@]}"; do
    if echo "$response" | jq -e ".$field" > /dev/null; then
        echo "✅ $field present"
    else
        echo "❌ $field missing"
    fi
done

# Check submission structure
echo ""
echo "Checking submission structure..."
submission_fields=("fileName" "ingestionFileId" "submissionDate" "claimInfo" "encounterInfo" "diagnosisInfo" "activitiesInfo" "attachments")
for field in "${submission_fields[@]}"; do
    if echo "$response" | jq -e ".submission.$field" > /dev/null; then
        echo "✅ submission.$field present"
    else
        echo "❌ submission.$field missing"
    fi
done

# Check resubmission structure
echo ""
echo "Checking resubmission structure..."
resubmission_fields=("fileName" "ingestionFileId" "claimEventId" "resubmissionDate" "resubmissionType" "resubmissionComment" "activitiesInfo" "attachments")
for field in "${resubmission_fields[@]}"; do
    if echo "$response" | jq -e ".resubmissions[0].$field" > /dev/null 2>&1; then
        echo "✅ resubmissions[0].$field present"
    else
        echo "ℹ️  resubmissions[0].$field not applicable (no resubmissions)"
    fi
done

# Check remittance structure
echo ""
echo "Checking remittance structure..."
remittance_fields=("fileName" "ingestionFileId" "remittanceId" "remittanceClaimId" "remittanceDate" "paymentReference" "settlementDate" "denialCode" "activities" "attachments")
for field in "${remittance_fields[@]}"; do
    if echo "$response" | jq -e ".remittances[0].$field" > /dev/null 2>&1; then
        echo "✅ remittances[0].$field present"
    else
        echo "ℹ️  remittances[0].$field not applicable (no remittances)"
    fi
done
```

## Performance Testing

### Load Testing with Apache Bench
```bash
# Test with 100 requests, 10 concurrent
ab -n 100 -c 10 http://localhost:8080/api/report-data/claim/TEST_CLAIM_001

# Test with different claim IDs
for claim_id in TEST_CLAIM_001 TEST_CLAIM_002 CLM-000051; do
    echo "Testing $claim_id..."
    ab -n 50 -c 5 "http://localhost:8080/api/report-data/claim/$claim_id"
done
```

## Error Handling Testing

### Test Cases
1. **404 - Claim Not Found**
   ```bash
   curl -i http://localhost:8080/api/report-data/claim/NON_EXISTENT_CLAIM
   ```

2. **400 - Invalid Claim ID Format**
   ```bash
   curl -i http://localhost:8080/api/report-data/claim/invalid-format
   ```

3. **500 - Database Connection Issues**
   - Stop database and test error handling

## Validation Checklist

### ✅ Response Structure
- [ ] `claimId` field present
- [ ] `submission` object contains all required fields
- [ ] `resubmissions` array (empty or populated)
- [ ] `remittances` array (empty or populated)
- [ ] `claimTimeline` preserved for backward compatibility
- [ ] `metadata` contains execution information

### ✅ Data Accuracy
- [ ] File names correctly associated with each event
- [ ] Event times match transaction dates from headers
- [ ] Activity snapshots in resubmissions come from `claim_event_activity`
- [ ] Payment amounts and denial codes accurate in remittances
- [ ] Chronological ordering maintained (ASC by event_time)

### ✅ Performance
- [ ] Response time < 500ms for typical claims
- [ ] Response time < 2s for complex claims with multiple events
- [ ] Memory usage stable under load
- [ ] Database queries optimized

### ✅ Error Handling
- [ ] 404 for non-existent claims
- [ ] 400 for invalid claim ID formats
- [ ] 500 for database errors
- [ ] Proper error messages in response

## Troubleshooting

### Common Issues

**Application won't start**:
```bash
# Check logs
docker-compose logs app

# Check database connection
docker-compose logs postgres
```

**No test data**:
```sql
-- Run test data setup
\i src/main/resources/db/dummy_data_for_reports.sql
\i src/main/resources/db/remittance_advice_payerwise_validation_test.sql
```

**API returns empty response**:
- Check if claim exists: `SELECT * FROM claims.claim_key WHERE claim_id = 'YOUR_CLAIM_ID'`
- Check claim events: `SELECT * FROM claims.claim_event WHERE claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = 'YOUR_CLAIM_ID')`

**Performance issues**:
- Check database indexes: `\di claims.*`
- Monitor query execution: Enable SQL logging in application.yml

## Success Criteria

The enhanced API is working correctly when:

1. ✅ **Structure**: Response follows the new format with `submission`, `resubmissions[]`, `remittances[]`
2. ✅ **Data Integrity**: File names, event times, and activity data are accurate
3. ✅ **Ordering**: Arrays maintain chronological order by `event_time`
4. ✅ **Performance**: Response times are acceptable (< 500ms typical, < 2s complex)
5. ✅ **Compatibility**: `claimTimeline` preserved for existing consumers
6. ✅ **Error Handling**: Proper HTTP status codes and error messages

## Next Steps

After successful testing:

1. **Documentation**: Update API documentation with new response format
2. **Client Updates**: Update frontend applications to use new structure
3. **Monitoring**: Set up monitoring for the enhanced endpoint
4. **Performance**: Monitor and optimize based on real-world usage
5. **Deprecation**: Plan deprecation timeline for old response format (if needed)

---

**Note**: This testing guide assumes the application is running with security disabled. If security is enabled, add appropriate authentication headers to all requests.
