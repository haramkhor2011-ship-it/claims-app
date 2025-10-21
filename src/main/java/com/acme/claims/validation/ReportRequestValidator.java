package com.acme.claims.validation;

import com.acme.claims.exception.InvalidDateRangeException;
import com.acme.claims.exception.InvalidReportParametersException;
import com.acme.claims.security.ReportType;
import lombok.experimental.UtilityClass;
import lombok.extern.slf4j.Slf4j;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Utility class for validating report request parameters.
 * 
 * This class provides static methods for validating various aspects of report requests,
 * including date ranges, pagination, facility access, and report-specific parameters.
 * 
 * All validation methods throw appropriate exceptions with detailed error messages
 * when validation fails.
 */
@Slf4j
@UtilityClass
public class ReportRequestValidator {
    
    // Valid tab names for each report type
    private static final Set<String> BALANCE_AMOUNT_TABS = Set.of("overall", "initial_not_remitted", "post_resubmission");
    private static final Set<String> REJECTED_CLAIMS_TABS = Set.of("summary", "receiverPayer", "claimWise");
    private static final Set<String> CLAIM_DETAILS_TABS = Set.of("details");
    private static final Set<String> DOCTOR_DENIAL_TABS = Set.of("high_denial", "summary", "detail");
    private static final Set<String> REMITTANCES_RESUBMISSION_TABS = Set.of("activity_level", "claim_level");
    private static final Set<String> CLAIM_SUMMARY_MONTHWISE_TABS = Set.of("monthwise", "payerwise", "encounterwise");
    private static final Set<String> REMITTANCE_ADVICE_PAYERWISE_TABS = Set.of("header", "claimWise", "activityWise");
    
    // Valid levels for level-based reports
    private static final Set<String> VALID_LEVELS = Set.of("activity", "claim");
    
    /**
     * Validates that the date range is valid (fromDate <= toDate).
     * 
     * @param fromDate the start date
     * @param toDate the end date
     * @throws InvalidDateRangeException if the date range is invalid
     */
    public static void validateDateRange(LocalDateTime fromDate, LocalDateTime toDate) {
        if (fromDate != null && toDate != null && fromDate.isAfter(toDate)) {
            throw new InvalidDateRangeException(
                "From date cannot be after to date. From: " + fromDate + ", To: " + toDate,
                fromDate, toDate
            );
        }
        
        // Check if date range is too large (more than 5 years)
        if (fromDate != null && toDate != null) {
            LocalDateTime fiveYearsLater = fromDate.plusYears(5);
            if (toDate.isAfter(fiveYearsLater)) {
                throw new InvalidDateRangeException(
                    "Date range cannot exceed 5 years. Maximum allowed: " + fiveYearsLater,
                    fromDate, toDate
                );
            }
        }
    }
    
    /**
     * Validates pagination parameters and applies sensible defaults.
     * 
     * @param page the page number
     * @param size the page size
     * @return array with validated [page, size]
     */
    public static int[] validatePagination(Integer page, Integer size) {
        // Apply defaults
        int validatedPage = page != null ? page : 0;
        int validatedSize = size != null ? size : 50;
        
        // Ensure page is not negative
        if (validatedPage < 0) {
            validatedPage = 0;
        }
        
        // Ensure size is within reasonable bounds
        if (validatedSize < 1) {
            validatedSize = 50;
        } else if (validatedSize > 1000) {
            validatedSize = 1000;
        }
        
        return new int[]{validatedPage, validatedSize};
    }
    
    /**
     * Validates facility access for the user.
     * 
     * @param requestedFacilities the facilities requested by the user
     * @param userFacilities the facilities the user has access to
     * @throws InvalidReportParametersException if user doesn't have access to requested facilities
     */
    public static void validateFacilityAccess(List<String> requestedFacilities, Set<String> userFacilities) {
        if (requestedFacilities == null || requestedFacilities.isEmpty()) {
            return; // No facilities requested, validation passes
        }
        
        if (userFacilities == null || userFacilities.isEmpty()) {
            // User has no facility restrictions, allow all
            return;
        }
        
        // Check if all requested facilities are accessible
        List<String> inaccessibleFacilities = new ArrayList<>();
        for (String facility : requestedFacilities) {
            if (!userFacilities.contains(facility)) {
                inaccessibleFacilities.add(facility);
            }
        }
        
        if (!inaccessibleFacilities.isEmpty()) {
            throw new InvalidReportParametersException(
                "User does not have access to facilities: " + inaccessibleFacilities
            );
        }
    }
    
    /**
     * Validates that the tab name is valid for the given report type.
     * 
     * @param reportType the report type
     * @param tab the tab name
     * @throws InvalidReportParametersException if the tab is invalid for the report type
     */
    public static void validateTabForReportType(ReportType reportType, String tab) {
        if (tab == null || tab.trim().isEmpty()) {
            return; // No tab specified, validation passes
        }
        
        Set<String> validTabs = getValidTabsForReportType(reportType);
        if (!validTabs.contains(tab)) {
            throw new InvalidReportParametersException(
                "Invalid tab '" + tab + "' for report type '" + reportType + 
                "'. Valid tabs: " + validTabs
            );
        }
    }
    
    /**
     * Validates that the level is valid for the given report type.
     * 
     * @param reportType the report type
     * @param level the level name
     * @throws InvalidReportParametersException if the level is invalid for the report type
     */
    public static void validateLevelForReportType(ReportType reportType, String level) {
        if (level == null || level.trim().isEmpty()) {
            return; // No level specified, validation passes
        }
        
        // Only REMITTANCES_RESUBMISSION supports levels
        if (reportType == ReportType.REMITTANCES_RESUBMISSION) {
            if (!VALID_LEVELS.contains(level)) {
                throw new InvalidReportParametersException(
                    "Invalid level '" + level + "' for report type '" + reportType + 
                    "'. Valid levels: " + VALID_LEVELS
                );
            }
        } else {
            throw new InvalidReportParametersException(
                "Level parameter is not supported for report type '" + reportType + "'"
            );
        }
    }
    
    /**
     * Validates year and month parameters.
     * 
     * @param year the year
     * @param month the month
     * @throws InvalidReportParametersException if year or month is invalid
     */
    public static void validateYearMonth(Integer year, Integer month) {
        if (year != null && (year < 1 || year > 9999)) {
            throw new InvalidReportParametersException(
                "Year must be between 1 and 9999. Provided: " + year
            );
        }
        
        if (month != null && (month < 1 || month > 12)) {
            throw new InvalidReportParametersException(
                "Month must be between 1 and 12. Provided: " + month
            );
        }
        
        // If both year and month are provided, validate they make sense together
        if (year != null && month != null) {
            LocalDateTime date = LocalDateTime.of(year, month, 1, 0, 0);
            LocalDateTime now = LocalDateTime.now();
            
            if (date.isAfter(now)) {
                throw new InvalidReportParametersException(
                    "Year and month combination cannot be in the future. Provided: " + year + "-" + month
                );
            }
        }
    }
    
    /**
     * Validates sort direction parameter.
     * 
     * @param sortDirection the sort direction
     * @return validated sort direction (defaults to "ASC" if invalid)
     */
    public static String validateSortDirection(String sortDirection) {
        if (sortDirection == null || sortDirection.trim().isEmpty()) {
            return "ASC";
        }
        
        String upperDirection = sortDirection.toUpperCase();
        if ("ASC".equals(upperDirection) || "DESC".equals(upperDirection)) {
            return upperDirection;
        }
        
        log.warn("Invalid sort direction '{}', defaulting to ASC", sortDirection);
        return "ASC";
    }
    
    /**
     * Validates that list parameters are not too large.
     * 
     * @param list the list to validate
     * @param maxSize the maximum allowed size
     * @param parameterName the name of the parameter for error messages
     * @throws InvalidReportParametersException if the list is too large
     */
    public static void validateListSize(List<?> list, int maxSize, String parameterName) {
        if (list != null && list.size() > maxSize) {
            throw new InvalidReportParametersException(
                parameterName + " cannot contain more than " + maxSize + " items. Provided: " + list.size()
            );
        }
    }
    
    /**
     * Gets the valid tabs for a given report type.
     * 
     * @param reportType the report type
     * @return set of valid tab names
     */
    private static Set<String> getValidTabsForReportType(ReportType reportType) {
        return switch (reportType) {
            case BALANCE_AMOUNT_REPORT -> BALANCE_AMOUNT_TABS;
            case REJECTED_CLAIMS_REPORT -> REJECTED_CLAIMS_TABS;
            case CLAIM_DETAILS_WITH_ACTIVITY -> CLAIM_DETAILS_TABS;
            case DOCTOR_DENIAL_REPORT -> DOCTOR_DENIAL_TABS;
            case REMITTANCES_RESUBMISSION -> REMITTANCES_RESUBMISSION_TABS;
            case CLAIM_SUMMARY_MONTHWISE -> CLAIM_SUMMARY_MONTHWISE_TABS;
            case REMITTANCE_ADVICE_PAYERWISE -> REMITTANCE_ADVICE_PAYERWISE_TABS;
            default -> Set.of(); // No tabs supported
        };
    }
    
    /**
     * Validates that the report type supports the requested operation.
     * 
     * @param reportType the report type
     * @param operation the operation (e.g., "tab", "level")
     * @param value the value being validated
     * @throws InvalidReportParametersException if the operation is not supported
     */
    public static void validateReportTypeSupport(ReportType reportType, String operation, String value) {
        switch (operation) {
            case "tab" -> validateTabForReportType(reportType, value);
            case "level" -> validateLevelForReportType(reportType, value);
            default -> {
                // Unknown operation, log warning but don't fail
                log.warn("Unknown validation operation '{}' for report type '{}'", operation, reportType);
            }
        }
    }
}

