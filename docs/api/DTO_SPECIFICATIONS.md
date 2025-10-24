# DTO Specifications

This document provides comprehensive specifications for all Data Transfer Objects (DTOs) used in the Claims Backend API, including validation rules, field descriptions, and usage examples.

## Overview

DTOs serve as the contract between the API and clients, ensuring data integrity and providing clear documentation of request/response formats. All DTOs include comprehensive validation annotations and OpenAPI documentation.

---

## Base DTOs

### ReportQueryRequest

**Purpose**: Unified base class for all report request DTOs
**Package**: `com.acme.claims.controller.dto`
**Extends**: None (base class)

**Key Features**:
- Comprehensive validation annotations
- Support for all report types
- Flexible filtering options
- Pagination and sorting
- Swagger documentation

**Fields**:

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `reportType` | `ReportType` | Yes | `@NotNull` | Type of report to retrieve |
| `tab` | `String` | No | Pattern: `^(summary\|receiverPayer\|claimWise)?$` | Tab name for tabbed reports |
| `level` | `String` | No | Pattern: `^(activity\|claim)?$` | Level for level-based reports |
| `facilityCode` | `String` | No | - | Single facility code filter |
| `facilityCodes` | `List<String>` | No | `@Size(max=100)` | List of facility codes |
| `facilityRefIds` | `List<Long>` | No | `@Size(max=100)` | List of facility reference IDs |
| `payerCode` | `String` | No | - | Single payer code filter |
| `payerCodes` | `List<String>` | No | `@Size(max=100)` | List of payer codes |
| `payerRefIds` | `List<Long>` | No | `@Size(max=100)` | List of payer reference IDs |
| `receiverCode` | `String` | No | - | Single receiver code filter |
| `receiverIds` | `List<String>` | No | `@Size(max=100)` | List of receiver IDs |
| `clinicianCode` | `String` | No | - | Single clinician code filter |
| `clinicianIds` | `List<String>` | No | `@Size(max=100)` | List of clinician IDs |
| `clinicianRefIds` | `List<Long>` | No | `@Size(max=100)` | List of clinician reference IDs |
| `claimId` | `String` | No | - | Specific claim ID filter |
| `patientId` | `String` | No | - | Patient ID filter |
| `cptCode` | `String` | No | - | CPT code filter |
| `paymentReference` | `String` | No | - | Payment reference filter |
| `denialCodes` | `List<String>` | No | `@Size(max=50)` | List of denial codes |
| `denialFilter` | `String` | No | - | Denial filter type |
| `encounterType` | `String` | No | - | Encounter type filter |
| `resubType` | `String` | No | - | Resubmission type filter |
| `claimStatus` | `String` | No | - | Claim status filter |
| `paymentStatus` | `String` | No | - | Payment status filter |
| `fromDate` | `LocalDateTime` | No | `@PastOrPresent` | Start date for filtering |
| `toDate` | `LocalDateTime` | No | `@FutureOrPresent` | End date for filtering |
| `year` | `Integer` | No | `@Min(1) @Max(9999)` | Year filter |
| `month` | `Integer` | No | `@Min(1) @Max(12)` | Month filter |
| `claimKeyIds` | `List<Long>` | No | `@Size(max=1000)` | List of claim key IDs |
| `basedOnInitialNet` | `Boolean` | No | - | Whether to base calculations on initial net |
| `sortBy` | `String` | No | - | Column name to sort by |
| `sortDirection` | `String` | No | Pattern: `^(ASC\|DESC)$` | Sort direction |
| `page` | `Integer` | No | `@Min(0)` | Page number (0-based) |
| `size` | `Integer` | No | `@Min(1) @Max(1000)` | Number of records per page |
| `extra` | `Map<String, Object>` | No | - | Additional parameters |

**Validation Rules**:
- `reportType`: Must be one of the valid report types
- `fromDate`: Cannot be in the future
- `toDate`: Cannot be in the past
- `year`: Must be between 1 and 9999
- `month`: Must be between 1 and 12
- `sortDirection`: Must be ASC or DESC
- `page`: Must be 0 or greater
- `size`: Must be between 1 and 1000
- Array fields: Limited to prevent performance issues

**Example Usage**:
```json
{
  "reportType": "BALANCE_AMOUNT_REPORT",
  "tab": "overall",
  "facilityCodes": ["FAC001", "FAC002"],
  "payerCodes": ["DHA", "ADNOC"],
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "year": 2025,
  "month": 6,
  "basedOnInitialNet": true,
  "sortBy": "aging_days",
  "sortDirection": "DESC",
  "page": 0,
  "size": 50
}
```

---

## Report-Specific DTOs

### ClaimDetailsWithActivityRequest

**Purpose**: Request DTO for Claim Details with Activity Report
**Package**: `com.acme.claims.controller.dto`
**Extends**: `ReportQueryRequest`

**Additional Fields**:

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `receiverId` | `String` | No | - | Receiver ID filter |
| `clinician` | `String` | No | - | Clinician filter |
| `memberId` | `String` | No | - | Member ID filter |
| `resubType` | `String` | No | - | Resubmission type filter |
| `claimStatus` | `String` | No | - | Claim status filter |
| `paymentStatus` | `String` | No | - | Payment status filter |
| `cptCode` | `String` | No | - | CPT code filter |
| `patientId` | `String` | No | - | Patient ID filter |
| `encounterType` | `String` | No | - | Encounter type filter |
| `denialCode` | `String` | No | - | Denial code filter |
| `facilityCode` | `String` | No | - | Facility code filter |
| `payerCode` | `String` | No | - | Payer code filter |
| `claimId` | `String` | No | - | Claim ID filter |
| `fromDate` | `LocalDateTime` | No | `@PastOrPresent` | Start date for filtering |
| `toDate` | `LocalDateTime` | No | `@FutureOrPresent` | End date for filtering |
| `sortBy` | `String` | No | - | Column name to sort by |
| `sortDirection` | `String` | No | Pattern: `^(ASC\|DESC)$` | Sort direction |
| `page` | `Integer` | No | `@Min(0)` | Page number (0-based) |
| `size` | `Integer` | No | `@Min(1) @Max(1000)` | Number of records per page |
| `extra` | `Map<String, Object>` | No | - | Additional parameters |

**Constructor**: Automatically sets `reportType` to `CLAIM_DETAILS_WITH_ACTIVITY`

**Example Usage**:
```json
{
  "reportType": "CLAIM_DETAILS_WITH_ACTIVITY",
  "level": "activity",
  "facilityCodes": ["FAC001"],
  "payerCodes": ["DHA"],
  "receiverId": "PROV001",
  "clinician": "DR001",
  "memberId": "MEM123",
  "resubType": "CORRECTED",
  "claimStatus": "SUBMITTED",
  "paymentStatus": "PENDING",
  "cptCode": "99213",
  "patientId": "PAT789",
  "encounterType": "OUTPATIENT",
  "denialCode": "CO-4",
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "sortBy": "submission_date",
  "sortDirection": "DESC",
  "page": 0,
  "size": 50
}
```

### RemittancesResubmissionRequest

**Purpose**: Request DTO for Remittances Resubmission Report
**Package**: `com.acme.claims.controller.dto`
**Extends**: `ReportQueryRequest`

**Additional Fields**:

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `facilityId` | `String` | No | - | Single facility ID filter |
| `facilityIds` | `List<String>` | No | `@Size(max=100)` | List of facility IDs |
| `payerIds` | `List<String>` | No | `@Size(max=100)` | List of payer IDs |
| `receiverIds` | `List<String>` | No | `@Size(max=100)` | List of receiver IDs |
| `clinicianIds` | `List<String>` | No | `@Size(max=100)` | List of clinician IDs |
| `claimNumber` | `String` | No | - | Claim number filter |
| `cptCode` | `String` | No | - | CPT code filter |
| `denialFilter` | `String` | No | - | Denial filter type |
| `encounterType` | `String` | No | - | Encounter type filter |
| `level` | `String` | No | Pattern: `^(activity\|claim)?$` | Level for level-based reports |
| `fromDate` | `LocalDateTime` | No | `@PastOrPresent` | Start date for filtering |
| `toDate` | `LocalDateTime` | No | `@FutureOrPresent` | End date for filtering |
| `orderBy` | `String` | No | - | Column name to sort by |
| `page` | `Integer` | No | `@Min(0)` | Page number (0-based) |
| `size` | `Integer` | No | `@Min(1) @Max(1000)` | Number of records per page |
| `facilityRefIds` | `List<Long>` | No | `@Size(max=100)` | List of facility reference IDs |
| `payerRefIds` | `List<Long>` | No | `@Size(max=100)` | List of payer reference IDs |
| `clinicianRefIds` | `List<Long>` | No | `@Size(max=100)` | List of clinician reference IDs |

**Constructor**: Automatically sets `reportType` to `REMITTANCES_RESUBMISSION`

**Example Usage**:
```json
{
  "reportType": "REMITTANCES_RESUBMISSION",
  "facilityIds": ["FAC001"],
  "payerIds": ["DHA"],
  "receiverIds": ["PROV001"],
  "clinicianIds": ["DR001"],
  "claimNumber": "CLM123456",
  "cptCode": "99213",
  "denialFilter": "rejected",
  "encounterType": "OUTPATIENT",
  "level": "activity",
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "orderBy": "encounter_start",
  "page": 0,
  "size": 50,
  "facilityRefIds": [123],
  "payerRefIds": [456],
  "clinicianRefIds": [789]
}
```

---

## Reference Data DTOs

### BaseReferenceDataRequest

**Purpose**: Base request DTO for CRUD operations on reference data
**Package**: `com.acme.claims.controller.dto`
**Extends**: None (base class)

**Fields**:

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `code` | `String` | Yes | `@NotBlank`, `@Size(1-50)`, Pattern: `^[a-zA-Z0-9_-]+$` | Code/identifier for the reference data item |
| `name` | `String` | Yes | `@NotBlank`, `@Size(1-255)`, Pattern: `^[a-zA-Z0-9\\s._-]+$` | Name/description of the reference data item |
| `status` | `String` | No | Pattern: `^(ACTIVE\|INACTIVE)$`, Default: `ACTIVE` | Status of the reference data item |

**Validation Rules**:
- `code`: Required, 1-50 characters, alphanumeric with underscores and hyphens only
- `name`: Required, 1-255 characters, alphanumeric with spaces, dots, underscores, and hyphens
- `status`: Must be ACTIVE or INACTIVE, defaults to ACTIVE

**Example Usage**:
```json
{
  "code": "FAC001",
  "name": "Dubai Hospital",
  "status": "ACTIVE"
}
```

### ReferenceDataRequest

**Purpose**: Request DTO for reference data lookup endpoints
**Package**: `com.acme.claims.controller.dto`
**Extends**: None (standalone DTO)

**Fields**:

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `searchTerm` | `String` | No | Pattern: `^[a-zA-Z0-9\\s._-]{0,100}$` | Search term to look for in code and name fields |
| `status` | `String` | No | Pattern: `^(ACTIVE\|INACTIVE)?$` | Status filter |
| `page` | `Integer` | No | `@Min(0) @Max(1000)`, Default: `0` | Page number (0-based) |
| `size` | `Integer` | No | `@Min(1) @Max(100)`, Default: `20` | Number of items per page |
| `sortBy` | `String` | No | Pattern: `^(code\|name\|createdAt\|updatedAt)?$`, Default: `code` | Sort field |
| `sortDirection` | `String` | No | Pattern: `^(ASC\|DESC)?$`, Default: `ASC` | Sort direction |
| `additionalFilters` | `Object` | No | - | Additional filters specific to the reference data type |

**Validation Rules**:
- `searchTerm`: 0-100 characters, alphanumeric with spaces, dots, underscores, and hyphens
- `status`: Must be ACTIVE, INACTIVE, or empty
- `page`: Must be 0-1000, defaults to 0
- `size`: Must be 1-100, defaults to 20
- `sortBy`: Must be code, name, createdAt, updatedAt, or empty
- `sortDirection`: Must be ASC, DESC, or empty

**Example Usage**:
```json
{
  "searchTerm": "hospital",
  "status": "ACTIVE",
  "page": 0,
  "size": 20,
  "sortBy": "name",
  "sortDirection": "ASC",
  "additionalFilters": {
    "facilityType": "HOSPITAL"
  }
}
```

---

## Specialized Reference Data DTOs

### FacilityRequest

**Purpose**: Request DTO for facility-specific operations
**Package**: `com.acme.claims.controller.dto`
**Extends**: `BaseReferenceDataRequest`

**Additional Fields**:
- Inherits all fields from `BaseReferenceDataRequest`
- May include facility-specific fields like location, type, etc.

### ClinicianRequest

**Purpose**: Request DTO for clinician-specific operations
**Package**: `com.acme.claims.controller.dto`
**Extends**: `BaseReferenceDataRequest`

**Additional Fields**:
- Inherits all fields from `BaseReferenceDataRequest`
- May include clinician-specific fields like specialty, license number, etc.

### PayerRequest

**Purpose**: Request DTO for payer-specific operations
**Package**: `com.acme.claims.controller.dto`
**Extends**: `BaseReferenceDataRequest`

**Additional Fields**:
- Inherits all fields from `BaseReferenceDataRequest`
- May include payer-specific fields like contact information, payment terms, etc.

### DenialCodeRequest

**Purpose**: Request DTO for denial code-specific operations
**Package**: `com.acme.claims.controller.dto`
**Extends**: `BaseReferenceDataRequest`

**Additional Fields**:
- Inherits all fields from `BaseReferenceDataRequest`
- May include denial code-specific fields like category, description, etc.

### ActivityCodeRequest

**Purpose**: Request DTO for activity code-specific operations
**Package**: `com.acme.claims.controller.dto`
**Extends**: `BaseReferenceDataRequest`

**Additional Fields**:
- Inherits all fields from `BaseReferenceDataRequest`
- May include activity code-specific fields like category, description, etc.

### DiagnosisCodeRequest

**Purpose**: Request DTO for diagnosis code-specific operations
**Package**: `com.acme.claims.controller.dto`
**Extends**: `BaseReferenceDataRequest`

**Additional Fields**:
- Inherits all fields from `BaseReferenceDataRequest`
- May include diagnosis code-specific fields like category, description, etc.

---

## Response DTOs

### ReportResponse

**Purpose**: Standard response format for all report endpoints
**Package**: `com.acme.claims.controller.dto`

**Structure**:
```json
{
  "success": true,
  "data": {
    "reportType": "BALANCE_AMOUNT_REPORT",
    "tab": "overall",
    "records": [...],
    "pagination": {
      "page": 0,
      "size": 50,
      "totalRecords": 1250,
      "totalPages": 25
    },
    "filters": {
      "applied": {...},
      "available": {...}
    },
    "metadata": {
      "generatedAt": "2025-01-15T10:30:00Z",
      "executionTimeMs": 245,
      "materializedViewUsed": true
    }
  }
}
```

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `success` | `Boolean` | Indicates if the request was successful |
| `data` | `Object` | Contains the report data and metadata |
| `data.reportType` | `String` | Type of report that was executed |
| `data.tab` | `String` | Tab that was requested |
| `data.records` | `Array` | Array of report records |
| `data.pagination` | `Object` | Pagination information |
| `data.pagination.page` | `Integer` | Current page number |
| `data.pagination.size` | `Integer` | Page size |
| `data.pagination.totalRecords` | `Long` | Total number of records |
| `data.pagination.totalPages` | `Integer` | Total number of pages |
| `data.filters` | `Object` | Applied and available filters |
| `data.metadata` | `Object` | Report execution metadata |
| `data.metadata.generatedAt` | `String` | Timestamp when report was generated |
| `data.metadata.executionTimeMs` | `Long` | Execution time in milliseconds |
| `data.metadata.materializedViewUsed` | `Boolean` | Whether materialized views were used |

### ErrorResponse

**Purpose**: Standard error response format
**Package**: `com.acme.claims.controller.dto`

**Structure**:
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid date range provided",
    "details": {
      "field": "fromDate",
      "value": "2026-01-01T00:00:00",
      "constraint": "Date cannot be in the future"
    },
    "timestamp": "2025-01-15T10:30:00Z"
  }
}
```

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `success` | `Boolean` | Always false for error responses |
| `error` | `Object` | Error information |
| `error.code` | `String` | Error code for programmatic handling |
| `error.message` | `String` | Human-readable error message |
| `error.details` | `Object` | Additional error details |
| `error.timestamp` | `String` | Timestamp when error occurred |

---

## Validation Rules Summary

### Common Validation Patterns

**String Patterns**:
- **Alphanumeric**: `^[a-zA-Z0-9]+$`
- **Alphanumeric with underscores/hyphens**: `^[a-zA-Z0-9_-]+$`
- **Alphanumeric with spaces**: `^[a-zA-Z0-9\\s._-]+$`
- **Sort direction**: `^(ASC|DESC)$`
- **Status values**: `^(ACTIVE|INACTIVE)$`

**Numeric Ranges**:
- **Page numbers**: `@Min(0) @Max(1000)`
- **Page sizes**: `@Min(1) @Max(1000)`
- **Years**: `@Min(1) @Max(9999)`
- **Months**: `@Min(1) @Max(12)`
- **Array sizes**: `@Size(max=100)` for most arrays, `@Size(max=1000)` for claim key IDs

**Date Validation**:
- **Past or present**: `@PastOrPresent` for fromDate
- **Future or present**: `@FutureOrPresent` for toDate

**Required Fields**:
- **Report type**: `@NotNull` for all report requests
- **Code**: `@NotBlank` for reference data CRUD operations
- **Name**: `@NotBlank` for reference data CRUD operations

### Environment-Specific Validation

**Local Development**:
- Validation may be relaxed for testing
- Debug information included in error responses
- Additional validation details in logs

**Production Environment**:
- Strict validation enforcement
- Sanitized error messages
- Comprehensive audit logging

---

## Usage Examples

### Report Request Example

```json
{
  "reportType": "BALANCE_AMOUNT_REPORT",
  "tab": "overall",
  "facilityCodes": ["FAC001", "FAC002"],
  "payerCodes": ["DHA", "ADNOC"],
  "receiverIds": ["PROV001"],
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "year": 2025,
  "month": 6,
  "basedOnInitialNet": true,
  "sortBy": "aging_days",
  "sortDirection": "DESC",
  "page": 0,
  "size": 50,
  "facilityRefIds": [123, 124],
  "payerRefIds": [456, 457]
}
```

### Reference Data Request Example

```json
{
  "searchTerm": "hospital",
  "status": "ACTIVE",
  "page": 0,
  "size": 20,
  "sortBy": "name",
  "sortDirection": "ASC",
  "additionalFilters": {
    "facilityType": "HOSPITAL",
    "location": "DUBAI"
  }
}
```

### Error Response Example

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request parameters",
    "details": {
      "field": "fromDate",
      "value": "2026-01-01T00:00:00",
      "constraint": "Date cannot be in the future",
      "field": "size",
      "value": 1500,
      "constraint": "Size cannot exceed 1000"
    },
    "timestamp": "2025-01-15T10:30:00Z"
  }
}
```

---

## Best Practices

### DTO Design

1. **Consistency**: Use consistent naming conventions across all DTOs
2. **Validation**: Include comprehensive validation annotations
3. **Documentation**: Provide clear field descriptions and examples
4. **Inheritance**: Use inheritance for common fields to reduce duplication
5. **Defaults**: Provide sensible default values where appropriate

### Validation Strategy

1. **Client-side**: Validate on the client for immediate feedback
2. **Server-side**: Always validate on the server for security
3. **Error Messages**: Provide clear, actionable error messages
4. **Field-level**: Validate individual fields with specific constraints
5. **Cross-field**: Validate relationships between fields when needed

### Environment Considerations

1. **Local Development**: Use relaxed validation for testing
2. **Production**: Enforce strict validation for security
3. **Error Handling**: Provide appropriate error details for each environment
4. **Logging**: Log validation failures for debugging
5. **Monitoring**: Monitor validation failure rates

---

## Related Documentation

- [Report API Reference](REPORT_API_REFERENCE.md) - API endpoint documentation
- [Validation Rules](VALIDATION_RULES.md) - Detailed validation documentation
- [Environment Behavior Guide](ENVIRONMENT_BEHAVIOR_GUIDE.md) - Environment-specific behavior
- [Security Matrix](SECURITY_MATRIX.md) - Security validation details
