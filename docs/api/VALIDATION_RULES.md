# Validation Rules Guide

## Overview

This guide provides comprehensive documentation of all validation rules applied to report requests, including field validation, business rule validation, and environment-specific validation behaviors.

## Field Validation Rules

### Common Field Validations

#### Report Type Validation
```java
@NotNull(message = "Report type is required")
@Schema(description = "Type of report to generate", example = "BALANCE_AMOUNT")
private ReportType reportType;

// ReportType enum validation
public enum ReportType {
    BALANCE_AMOUNT,
    CLAIM_DETAILS_WITH_ACTIVITY,
    CLAIM_SUMMARY_MONTHWISE,
    DOCTOR_DENIAL,
    REJECTED_CLAIMS,
    REMITTANCE_ADVICE_PAYERWISE,
    REMITTANCES_RESUBMISSION
}
```

#### Facility Code Validation
```java
@NotBlank(message = "Facility code is required")
@Pattern(regexp = "^[A-Z0-9]{3,10}$", message = "Facility code must be 3-10 alphanumeric characters")
@Schema(description = "Facility code for filtering", example = "FAC001")
private String facilityCode;
```

#### Payer Code Validation
```java
@NotEmpty(message = "At least one payer code is required")
@Schema(description = "List of payer codes for filtering", example = "[\"PAYER001\", \"PAYER002\"]")
private List<@Pattern(regexp = "^[A-Z0-9]{3,10}$", message = "Invalid payer code format") String> payerCodes;
```

#### Date Range Validation
```java
@NotNull(message = "From date is required")
@PastOrPresent(message = "From date cannot be in the future")
@Schema(description = "Start date for report data", example = "2024-01-01T00:00:00Z")
private LocalDateTime fromDate;

@NotNull(message = "To date is required")
@FutureOrPresent(message = "To date cannot be in the past")
@Schema(description = "End date for report data", example = "2024-12-31T23:59:59Z")
private LocalDateTime toDate;
```

#### Pagination Validation
```java
@Min(value = 0, message = "Page number must be non-negative")
@Schema(description = "Page number for pagination", example = "0")
private Integer page = 0;

@Min(value = 1, message = "Page size must be at least 1")
@Max(value = 1000, message = "Page size cannot exceed 1000")
@Schema(description = "Number of records per page", example = "100")
private Integer size = 100;
```

#### Tab Validation
```java
@Pattern(regexp = "^[A-C]$", message = "Tab must be A, B, or C")
@Schema(description = "Report tab to display", example = "A")
private String tab = "A";
```

### Report-Specific Validations

#### Balance Amount Report Validation
```java
public class BalanceAmountRequest extends ReportQueryRequest {
    
    @Override
    @Pattern(regexp = "^[A-C]$", message = "Balance Amount Report supports tabs A, B, and C")
    public String getTab() {
        return super.getTab();
    }
    
    // Additional validation for balance amount specific fields
    @DecimalMin(value = "0.0", message = "Minimum amount must be non-negative")
    @DecimalMax(value = "999999.99", message = "Maximum amount cannot exceed 999,999.99")
    private BigDecimal minimumAmount;
    
    @DecimalMin(value = "0.0", message = "Maximum amount must be non-negative")
    @DecimalMax(value = "999999.99", message = "Maximum amount cannot exceed 999,999.99")
    private BigDecimal maximumAmount;
}
```

#### Rejected Claims Report Validation
```java
public class RejectedClaimsRequest extends ReportQueryRequest {
    
    @Override
    @Pattern(regexp = "^[A-C]$", message = "Rejected Claims Report supports tabs A, B, and C")
    public String getTab() {
        return super.getTab();
    }
    
    @Min(value = 0, message = "Denial threshold must be non-negative")
    @Max(value = 100, message = "Denial threshold cannot exceed 100%")
    private BigDecimal denialThreshold = BigDecimal.valueOf(15.0);
    
    @Pattern(regexp = "^[A-Z0-9]{2,10}$", message = "Invalid denial code format")
    private String denialCode;
}
```

#### Doctor Denial Report Validation
```java
public class DoctorDenialRequest extends ReportQueryRequest {
    
    @Override
    @Pattern(regexp = "^[A-C]$", message = "Doctor Denial Report supports tabs A, B, and C")
    public String getTab() {
        return super.getTab();
    }
    
    @Min(value = 0, message = "Denial threshold must be non-negative")
    @Max(value = 100, message = "Denial threshold cannot exceed 100%")
    private BigDecimal denialThreshold = BigDecimal.valueOf(15.0);
    
    @Pattern(regexp = "^[A-Z0-9]{3,10}$", message = "Invalid clinician code format")
    private String clinicianCode;
}
```

#### Claim Details with Activity Report Validation
```java
public class ClaimDetailsWithActivityRequest extends ReportQueryRequest {
    
    @Override
    @Pattern(regexp = "^[A-C]$", message = "Claim Details Report supports tabs A, B, and C")
    public String getTab() {
        return super.getTab();
    }
    
    @Pattern(regexp = "^(activity|claim)$", message = "Level must be 'activity' or 'claim'")
    private String level = "activity";
    
    @Pattern(regexp = "^[A-Z0-9]{3,10}$", message = "Invalid activity code format")
    private String activityCode;
}
```

## Business Rule Validation

### Date Range Business Rules
```java
@Component
public class DateRangeValidator implements ConstraintValidator<ValidDateRange, ReportQueryRequest> {
    
    @Override
    public boolean isValid(ReportQueryRequest request, ConstraintValidatorContext context) {
        if (request.getFromDate() == null || request.getToDate() == null) {
            return true; // Let @NotNull handle null validation
        }
        
        // Business rule: Date range cannot exceed 2 years
        Duration duration = Duration.between(request.getFromDate(), request.getToDate());
        if (duration.toDays() > 730) {
            context.disableDefaultConstraintViolation();
            context.buildConstraintViolationWithTemplate("Date range cannot exceed 2 years")
                   .addPropertyNode("toDate")
                   .addConstraintViolation();
            return false;
        }
        
        // Business rule: From date must be before to date
        if (request.getFromDate().isAfter(request.getToDate())) {
            context.disableDefaultConstraintViolation();
            context.buildConstraintViolationWithTemplate("From date must be before to date")
                   .addPropertyNode("fromDate")
                   .addConstraintViolation();
            return false;
        }
        
        return true;
    }
}
```

### Facility Access Validation
```java
@Component
public class FacilityAccessValidator {
    
    @Autowired
    private FacilityRepository facilityRepository;
    
    public void validateFacilityAccess(String facilityCode, Authentication authentication) {
        // Business rule: User must have access to the requested facility
        if (!hasFacilityAccess(facilityCode, authentication)) {
            throw new AccessDeniedException("Access denied to facility: " + facilityCode);
        }
        
        // Business rule: Facility must exist and be active
        Facility facility = facilityRepository.findByCode(facilityCode);
        if (facility == null) {
            throw new ValidationException("Facility not found: " + facilityCode);
        }
        
        if (!facility.isActive()) {
            throw new ValidationException("Facility is inactive: " + facilityCode);
        }
    }
    
    private boolean hasFacilityAccess(String facilityCode, Authentication authentication) {
        // Implementation depends on authentication context
        // Check if user has access to the facility
        return true; // Simplified for example
    }
}
```

### Payer Code Validation
```java
@Component
public class PayerCodeValidator {
    
    @Autowired
    private PayerRepository payerRepository;
    
    public void validatePayerCodes(List<String> payerCodes) {
        if (payerCodes == null || payerCodes.isEmpty()) {
            return; // Optional field
        }
        
        // Business rule: All payer codes must exist and be active
        for (String payerCode : payerCodes) {
            Payer payer = payerRepository.findByCode(payerCode);
            if (payer == null) {
                throw new ValidationException("Payer not found: " + payerCode);
            }
            
            if (!payer.isActive()) {
                throw new ValidationException("Payer is inactive: " + payerCode);
            }
        }
        
        // Business rule: Maximum 10 payer codes per request
        if (payerCodes.size() > 10) {
            throw new ValidationException("Maximum 10 payer codes allowed per request");
        }
    }
}
```

### Tab Validation per Report Type
```java
@Component
public class TabValidator {
    
    private static final Map<ReportType, Set<String>> VALID_TABS = Map.of(
        ReportType.BALANCE_AMOUNT, Set.of("A", "B", "C"),
        ReportType.REJECTED_CLAIMS, Set.of("A", "B", "C"),
        ReportType.DOCTOR_DENIAL, Set.of("A", "B", "C"),
        ReportType.CLAIM_DETAILS_WITH_ACTIVITY, Set.of("A", "B", "C"),
        ReportType.CLAIM_SUMMARY_MONTHWISE, Set.of("A", "B", "C"),
        ReportType.REMITTANCE_ADVICE_PAYERWISE, Set.of("A", "B", "C"),
        ReportType.REMITTANCES_RESUBMISSION, Set.of("A", "B", "C")
    );
    
    public void validateTab(ReportType reportType, String tab) {
        Set<String> validTabs = VALID_TABS.get(reportType);
        if (validTabs == null) {
            throw new ValidationException("Invalid report type: " + reportType);
        }
        
        if (!validTabs.contains(tab)) {
            throw new ValidationException(
                String.format("Invalid tab '%s' for report type '%s'. Valid tabs: %s", 
                             tab, reportType, validTabs)
            );
        }
    }
}
```

## Environment-Specific Validation

### Local Development Validation
```java
@Profile("local")
@Component
public class LocalValidationConfig {
    
    @Bean
    public Validator localValidator() {
        ValidatorFactory factory = Validation.buildDefaultValidatorFactory();
        Validator validator = factory.getValidator();
        
        // Local development: Relaxed validation
        return validator;
    }
    
    @Bean
    public DateRangeValidator localDateRangeValidator() {
        return new DateRangeValidator() {
            @Override
            public boolean isValid(ReportQueryRequest request, ConstraintValidatorContext context) {
                // Local development: Allow longer date ranges for testing
                if (request.getFromDate() == null || request.getToDate() == null) {
                    return true;
                }
                
                Duration duration = Duration.between(request.getFromDate(), request.getToDate());
                if (duration.toDays() > 3650) { // 10 years for local testing
                    return false;
                }
                
                return true;
            }
        };
    }
}
```

### Production Validation
```java
@Profile("prod")
@Component
public class ProductionValidationConfig {
    
    @Bean
    public Validator productionValidator() {
        ValidatorFactory factory = Validation.buildDefaultValidatorFactory();
        Validator validator = factory.getValidator();
        
        // Production: Strict validation
        return validator;
    }
    
    @Bean
    public DateRangeValidator productionDateRangeValidator() {
        return new DateRangeValidator() {
            @Override
            public boolean isValid(ReportQueryRequest request, ConstraintValidatorContext context) {
                // Production: Strict date range validation
                if (request.getFromDate() == null || request.getToDate() == null) {
                    return true;
                }
                
                Duration duration = Duration.between(request.getFromDate(), request.getToDate());
                if (duration.toDays() > 730) { // 2 years max
                    return false;
                }
                
                // Production: Additional business rules
                if (request.getFromDate().isBefore(LocalDateTime.now().minusYears(5))) {
                    return false; // No data older than 5 years
                }
                
                return true;
            }
        };
    }
}
```

## Custom Validation Annotations

### Valid Date Range Annotation
```java
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = DateRangeValidator.class)
public @interface ValidDateRange {
    String message() default "Invalid date range";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
```

### Valid Facility Code Annotation
```java
@Target({ElementType.FIELD})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = FacilityCodeValidator.class)
public @interface ValidFacilityCode {
    String message() default "Invalid facility code";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
```

### Valid Payer Codes Annotation
```java
@Target({ElementType.FIELD})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = PayerCodesValidator.class)
public @interface ValidPayerCodes {
    String message() default "Invalid payer codes";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
```

## Validation Error Handling

### Global Exception Handler
```java
@RestControllerAdvice
public class ValidationExceptionHandler {
    
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationException(MethodArgumentNotValidException ex) {
        List<FieldError> fieldErrors = ex.getBindingResult().getFieldErrors();
        List<ObjectError> globalErrors = ex.getBindingResult().getGlobalErrors();
        
        ErrorResponse errorResponse = new ErrorResponse();
        errorResponse.setCode("VALIDATION_ERROR");
        errorResponse.setMessage("Validation failed");
        errorResponse.setTimestamp(LocalDateTime.now());
        
        List<ValidationError> validationErrors = new ArrayList<>();
        
        // Process field errors
        for (FieldError fieldError : fieldErrors) {
            ValidationError validationError = new ValidationError();
            validationError.setField(fieldError.getField());
            validationError.setRejectedValue(fieldError.getRejectedValue());
            validationError.setMessage(fieldError.getDefaultMessage());
            validationErrors.add(validationError);
        }
        
        // Process global errors
        for (ObjectError globalError : globalErrors) {
            ValidationError validationError = new ValidationError();
            validationError.setField(globalError.getObjectName());
            validationError.setMessage(globalError.getDefaultMessage());
            validationErrors.add(validationError);
        }
        
        errorResponse.setDetails(validationErrors);
        
        return ResponseEntity.badRequest().body(errorResponse);
    }
    
    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ErrorResponse> handleConstraintViolationException(ConstraintViolationException ex) {
        ErrorResponse errorResponse = new ErrorResponse();
        errorResponse.setCode("CONSTRAINT_VIOLATION");
        errorResponse.setMessage("Constraint violation");
        errorResponse.setTimestamp(LocalDateTime.now());
        
        List<ValidationError> validationErrors = new ArrayList<>();
        for (ConstraintViolation<?> violation : ex.getConstraintViolations()) {
            ValidationError validationError = new ValidationError();
            validationError.setField(violation.getPropertyPath().toString());
            validationError.setRejectedValue(violation.getInvalidValue());
            validationError.setMessage(violation.getMessage());
            validationErrors.add(validationError);
        }
        
        errorResponse.setDetails(validationErrors);
        
        return ResponseEntity.badRequest().body(errorResponse);
    }
}
```

### Error Response Format
```java
public class ErrorResponse {
    private String code;
    private String message;
    private LocalDateTime timestamp;
    private List<ValidationError> details;
    
    // Getters and setters
}

public class ValidationError {
    private String field;
    private Object rejectedValue;
    private String message;
    
    // Getters and setters
}
```

## Validation Testing

### Unit Tests for Validation
```java
@ExtendWith(MockitoExtension.class)
class ValidationTest {
    
    private Validator validator;
    
    @BeforeEach
    void setUp() {
        ValidatorFactory factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }
    
    @Test
    void testValidBalanceAmountRequest() {
        BalanceAmountRequest request = new BalanceAmountRequest();
        request.setReportType(ReportType.BALANCE_AMOUNT);
        request.setFacilityCode("FAC001");
        request.setPayerCodes(List.of("PAYER001"));
        request.setFromDate(LocalDateTime.now().minusMonths(1));
        request.setToDate(LocalDateTime.now());
        request.setTab("A");
        
        Set<ConstraintViolation<BalanceAmountRequest>> violations = validator.validate(request);
        
        assertTrue(violations.isEmpty());
    }
    
    @Test
    void testInvalidFacilityCode() {
        BalanceAmountRequest request = new BalanceAmountRequest();
        request.setReportType(ReportType.BALANCE_AMOUNT);
        request.setFacilityCode("INVALID_FACILITY_CODE_TOO_LONG");
        request.setPayerCodes(List.of("PAYER001"));
        request.setFromDate(LocalDateTime.now().minusMonths(1));
        request.setToDate(LocalDateTime.now());
        request.setTab("A");
        
        Set<ConstraintViolation<BalanceAmountRequest>> violations = validator.validate(request);
        
        assertFalse(violations.isEmpty());
        assertTrue(violations.stream()
                .anyMatch(v -> v.getPropertyPath().toString().equals("facilityCode")));
    }
    
    @Test
    void testInvalidDateRange() {
        BalanceAmountRequest request = new BalanceAmountRequest();
        request.setReportType(ReportType.BALANCE_AMOUNT);
        request.setFacilityCode("FAC001");
        request.setPayerCodes(List.of("PAYER001"));
        request.setFromDate(LocalDateTime.now().plusDays(1)); // Future date
        request.setToDate(LocalDateTime.now());
        request.setTab("A");
        
        Set<ConstraintViolation<BalanceAmountRequest>> violations = validator.validate(request);
        
        assertFalse(violations.isEmpty());
        assertTrue(violations.stream()
                .anyMatch(v -> v.getPropertyPath().toString().equals("fromDate")));
    }
}
```

### Integration Tests for Validation
```java
@SpringBootTest
@AutoConfigureTestDatabase
class ValidationIntegrationTest {
    
    @Autowired
    private TestRestTemplate restTemplate;
    
    @Test
    void testValidationErrorResponse() {
        BalanceAmountRequest request = new BalanceAmountRequest();
        request.setReportType(ReportType.BALANCE_AMOUNT);
        request.setFacilityCode("INVALID_FACILITY_CODE_TOO_LONG");
        request.setPayerCodes(List.of("PAYER001"));
        request.setFromDate(LocalDateTime.now().minusMonths(1));
        request.setToDate(LocalDateTime.now());
        request.setTab("A");
        
        ResponseEntity<ErrorResponse> response = restTemplate.postForEntity(
            "/api/reports/data/balance-amount",
            request,
            ErrorResponse.class
        );
        
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals("VALIDATION_ERROR", response.getBody().getCode());
        assertFalse(response.getBody().getDetails().isEmpty());
    }
}
```

## Best Practices

### Validation Best Practices
1. **Validate Early**: Validate input at the controller level
2. **Use Annotations**: Leverage Bean Validation annotations
3. **Custom Validators**: Create custom validators for complex business rules
4. **Environment-Specific**: Adjust validation rules based on environment
5. **Clear Messages**: Provide clear, actionable error messages

### Error Handling Best Practices
1. **Consistent Format**: Use consistent error response format
2. **Detailed Information**: Include field-level error details
3. **User-Friendly Messages**: Provide user-friendly error messages
4. **Logging**: Log validation errors for debugging
5. **Security**: Don't expose sensitive information in error messages

### Testing Best Practices
1. **Unit Tests**: Test individual validation rules
2. **Integration Tests**: Test validation in context
3. **Edge Cases**: Test boundary conditions
4. **Error Scenarios**: Test error handling paths
5. **Performance**: Test validation performance

## Related Documentation
- [API Reference](./REPORT_API_REFERENCE.md)
- [API Error Codes](./API_ERROR_CODES.md)
- [DTO Specifications](./DTO_SPECIFICATIONS.md)
- [Environment Behavior Guide](../reports/ENVIRONMENT_BEHAVIOR_GUIDE.md)
- [Security Matrix](../reports/SECURITY_MATRIX.md)
