package com.acme.claims.security;

/**
 * Enum representing different report types in the claims system.
 * Used for role-based access control to reports.
 */
public enum ReportType {
    
    BALANCE_AMOUNT_REPORT("Balance Amount Report", "Shows balance amounts to be received"),
    CLAIM_DETAILS_WITH_ACTIVITY("Claim Details With Activity", "Detailed claim information with activity timeline"),
    CLAIM_SUMMARY("Claim Summary", "Summary view of claims with key metrics"),
    DOCTOR_DENIAL_REPORT("Doctor Denial Report", "Reports on claims denied by doctors"),
    REJECTED_CLAIMS_REPORT("Rejected Claims Report", "Claims that were rejected during processing"),
    REMITTANCE_ADVICE_PAYERWISE("Remittance Advice Payerwise", "Remittance advice grouped by payer"),
    REMITTANCES_RESUBMISSION("Remittances & Resubmission", "Remittance and resubmission activity reports");
    
    private final String displayName;
    private final String description;
    
    ReportType(String displayName, String description) {
        this.displayName = displayName;
        this.description = description;
    }
    
    public String getDisplayName() {
        return displayName;
    }
    
    public String getDescription() {
        return description;
    }
    
    /**
     * Get report type by name (case-insensitive)
     */
    public static ReportType fromName(String name) {
        if (name == null) {
            return null;
        }
        
        for (ReportType type : values()) {
            if (type.name().equalsIgnoreCase(name)) {
                return type;
            }
        }
        
        throw new IllegalArgumentException("Unknown report type: " + name);
    }
}
