// FILE: src/main/java/com/acme/claims/domain/model/entity/ClaimPayment.java
// Version: v2.0.0
package com.acme.claims.domain.model.entity;

import com.acme.claims.domain.enums.PaymentStatus;
import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

/**
 * Entity representing aggregated financial summary and lifecycle tracking for claims
 * Maps to claims.claim_payment table
 * 
 * This entity provides a single source of truth for claim financial metrics,
 * eliminating the need for complex aggregations in materialized views and reports.
 * 
 * Key Features:
 * - ONE ROW PER CLAIM (enforced by unique constraint on claim_key_id)
 * - Pre-computed financial metrics (submitted, paid, rejected amounts)
 * - Activity-level counts (paid, partially paid, rejected, pending activities)
 * - Lifecycle tracking (remittance count, resubmission count, processing cycles)
 * - Date tracking (submission, remittance, payment dates)
 * - Performance metrics (days to payment, days to settlement)
 * - Payment references (latest and all payment references)
 */
@Entity
@Table(name = "claim_payment", schema = "claims")
public class ClaimPayment {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "claim_key_id", nullable = false, unique = true)
    private ClaimKey claimKey;
    
    // === FINANCIAL SUMMARY (aggregated from all remittances) ===
    @Column(name = "total_submitted_amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal totalSubmittedAmount = BigDecimal.ZERO;
    
    @Column(name = "total_paid_amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal totalPaidAmount = BigDecimal.ZERO;
    
    @Column(name = "total_remitted_amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal totalRemittedAmount = BigDecimal.ZERO;
    
    @Column(name = "total_rejected_amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal totalRejectedAmount = BigDecimal.ZERO;
    
    @Column(name = "total_denied_amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal totalDeniedAmount = BigDecimal.ZERO;
    
    // === ACTIVITY COUNTS ===
    @Column(name = "total_activities", nullable = false)
    private Integer totalActivities = 0;
    
    @Column(name = "paid_activities", nullable = false)
    private Integer paidActivities = 0;
    
    @Column(name = "partially_paid_activities", nullable = false)
    private Integer partiallyPaidActivities = 0;
    
    @Column(name = "rejected_activities", nullable = false)
    private Integer rejectedActivities = 0;
    
    @Column(name = "pending_activities", nullable = false)
    private Integer pendingActivities = 0;
    
    // === LIFECYCLE TRACKING ===
    @Column(name = "remittance_count", nullable = false)
    private Integer remittanceCount = 0;
    
    @Column(name = "resubmission_count", nullable = false)
    private Integer resubmissionCount = 0;
    
    // === CURRENT STATUS ===
    @Enumerated(EnumType.STRING)
    @Column(name = "payment_status", nullable = false, length = 20)
    private PaymentStatus paymentStatus = PaymentStatus.PENDING;
    
    // === LIFECYCLE DATES ===
    @Column(name = "first_submission_date")
    private LocalDate firstSubmissionDate;
    
    @Column(name = "last_submission_date")
    private LocalDate lastSubmissionDate;
    
    @Column(name = "first_remittance_date")
    private LocalDate firstRemittanceDate;
    
    @Column(name = "last_remittance_date")
    private LocalDate lastRemittanceDate;
    
    @Column(name = "first_payment_date")
    private LocalDate firstPaymentDate;
    
    @Column(name = "last_payment_date")
    private LocalDate lastPaymentDate;
    
    @Column(name = "latest_settlement_date")
    private LocalDate latestSettlementDate;
    
    // === LIFECYCLE METRICS ===
    @Column(name = "days_to_first_payment")
    private Integer daysToFirstPayment;
    
    @Column(name = "days_to_final_settlement")
    private Integer daysToFinalSettlement;
    
    @Column(name = "processing_cycles", nullable = false)
    private Integer processingCycles = 1;
    
    // === PAYMENT REFERENCES ===
    @Column(name = "latest_payment_reference", length = 100)
    private String latestPaymentReference;
    
    @ElementCollection
    @CollectionTable(name = "claim_payment_references", schema = "claims", 
                     joinColumns = @JoinColumn(name = "claim_payment_id"))
    @Column(name = "payment_reference")
    private List<String> paymentReferences;
    
    // === BUSINESS TRANSACTION TIME ===
    @Column(name = "tx_at", nullable = false)
    private OffsetDateTime txAt;
    
    // === AUDIT TIMESTAMPS ===
    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();
    
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();
    
    // === CONSTRUCTORS ===
    public ClaimPayment() {}
    
    public ClaimPayment(ClaimKey claimKey) {
        this.claimKey = claimKey;
        this.txAt = OffsetDateTime.now();
    }
    
    // === GETTERS AND SETTERS ===
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public ClaimKey getClaimKey() { return claimKey; }
    public void setClaimKey(ClaimKey claimKey) { this.claimKey = claimKey; }
    
    public BigDecimal getTotalSubmittedAmount() { return totalSubmittedAmount; }
    public void setTotalSubmittedAmount(BigDecimal totalSubmittedAmount) { this.totalSubmittedAmount = totalSubmittedAmount; }
    
    public BigDecimal getTotalPaidAmount() { return totalPaidAmount; }
    public void setTotalPaidAmount(BigDecimal totalPaidAmount) { this.totalPaidAmount = totalPaidAmount; }
    
    public BigDecimal getTotalRemittedAmount() { return totalRemittedAmount; }
    public void setTotalRemittedAmount(BigDecimal totalRemittedAmount) { this.totalRemittedAmount = totalRemittedAmount; }
    
    public BigDecimal getTotalRejectedAmount() { return totalRejectedAmount; }
    public void setTotalRejectedAmount(BigDecimal totalRejectedAmount) { this.totalRejectedAmount = totalRejectedAmount; }
    
    public BigDecimal getTotalDeniedAmount() { return totalDeniedAmount; }
    public void setTotalDeniedAmount(BigDecimal totalDeniedAmount) { this.totalDeniedAmount = totalDeniedAmount; }
    
    public Integer getTotalActivities() { return totalActivities; }
    public void setTotalActivities(Integer totalActivities) { this.totalActivities = totalActivities; }
    
    public Integer getPaidActivities() { return paidActivities; }
    public void setPaidActivities(Integer paidActivities) { this.paidActivities = paidActivities; }
    
    public Integer getPartiallyPaidActivities() { return partiallyPaidActivities; }
    public void setPartiallyPaidActivities(Integer partiallyPaidActivities) { this.partiallyPaidActivities = partiallyPaidActivities; }
    
    public Integer getRejectedActivities() { return rejectedActivities; }
    public void setRejectedActivities(Integer rejectedActivities) { this.rejectedActivities = rejectedActivities; }
    
    public Integer getPendingActivities() { return pendingActivities; }
    public void setPendingActivities(Integer pendingActivities) { this.pendingActivities = pendingActivities; }
    
    public Integer getRemittanceCount() { return remittanceCount; }
    public void setRemittanceCount(Integer remittanceCount) { this.remittanceCount = remittanceCount; }
    
    public Integer getResubmissionCount() { return resubmissionCount; }
    public void setResubmissionCount(Integer resubmissionCount) { this.resubmissionCount = resubmissionCount; }
    
    public PaymentStatus getPaymentStatus() { return paymentStatus; }
    public void setPaymentStatus(PaymentStatus paymentStatus) { this.paymentStatus = paymentStatus; }
    
    public LocalDate getFirstSubmissionDate() { return firstSubmissionDate; }
    public void setFirstSubmissionDate(LocalDate firstSubmissionDate) { this.firstSubmissionDate = firstSubmissionDate; }
    
    public LocalDate getLastSubmissionDate() { return lastSubmissionDate; }
    public void setLastSubmissionDate(LocalDate lastSubmissionDate) { this.lastSubmissionDate = lastSubmissionDate; }
    
    public LocalDate getFirstRemittanceDate() { return firstRemittanceDate; }
    public void setFirstRemittanceDate(LocalDate firstRemittanceDate) { this.firstRemittanceDate = firstRemittanceDate; }
    
    public LocalDate getLastRemittanceDate() { return lastRemittanceDate; }
    public void setLastRemittanceDate(LocalDate lastRemittanceDate) { this.lastRemittanceDate = lastRemittanceDate; }
    
    public LocalDate getFirstPaymentDate() { return firstPaymentDate; }
    public void setFirstPaymentDate(LocalDate firstPaymentDate) { this.firstPaymentDate = firstPaymentDate; }
    
    public LocalDate getLastPaymentDate() { return lastPaymentDate; }
    public void setLastPaymentDate(LocalDate lastPaymentDate) { this.lastPaymentDate = lastPaymentDate; }
    
    public LocalDate getLatestSettlementDate() { return latestSettlementDate; }
    public void setLatestSettlementDate(LocalDate latestSettlementDate) { this.latestSettlementDate = latestSettlementDate; }
    
    public Integer getDaysToFirstPayment() { return daysToFirstPayment; }
    public void setDaysToFirstPayment(Integer daysToFirstPayment) { this.daysToFirstPayment = daysToFirstPayment; }
    
    public Integer getDaysToFinalSettlement() { return daysToFinalSettlement; }
    public void setDaysToFinalSettlement(Integer daysToFinalSettlement) { this.daysToFinalSettlement = daysToFinalSettlement; }
    
    public Integer getProcessingCycles() { return processingCycles; }
    public void setProcessingCycles(Integer processingCycles) { this.processingCycles = processingCycles; }
    
    public String getLatestPaymentReference() { return latestPaymentReference; }
    public void setLatestPaymentReference(String latestPaymentReference) { this.latestPaymentReference = latestPaymentReference; }
    
    public List<String> getPaymentReferences() { return paymentReferences; }
    public void setPaymentReferences(List<String> paymentReferences) { this.paymentReferences = paymentReferences; }
    
    public OffsetDateTime getTxAt() { return txAt; }
    public void setTxAt(OffsetDateTime txAt) { this.txAt = txAt; }
    
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
    
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(OffsetDateTime updatedAt) { this.updatedAt = updatedAt; }
    
    // === BUSINESS METHODS ===
    
    /**
     * Calculate payment completion percentage
     * @return Percentage of claim amount that has been paid (0-100)
     */
    public BigDecimal getPaymentCompletionPercentage() {
        if (totalSubmittedAmount == null || totalSubmittedAmount.compareTo(BigDecimal.ZERO) == 0) {
            return BigDecimal.ZERO;
        }
        return totalPaidAmount.divide(totalSubmittedAmount, 4, BigDecimal.ROUND_HALF_UP)
                .multiply(BigDecimal.valueOf(100));
    }
    
    /**
     * Check if claim is fully paid
     * @return true if claim is fully paid
     */
    public boolean isFullyPaid() {
        return PaymentStatus.FULLY_PAID.equals(paymentStatus);
    }
    
    /**
     * Check if claim is partially paid
     * @return true if claim is partially paid
     */
    public boolean isPartiallyPaid() {
        return PaymentStatus.PARTIALLY_PAID.equals(paymentStatus);
    }
    
    /**
     * Check if claim is rejected
     * @return true if claim is rejected
     */
    public boolean isRejected() {
        return PaymentStatus.REJECTED.equals(paymentStatus);
    }
    
    /**
     * Check if claim is pending
     * @return true if claim is pending
     */
    public boolean isPending() {
        return PaymentStatus.PENDING.equals(paymentStatus);
    }
    
    /**
     * Check if claim has received any payment
     * @return true if claim has received payment (fully or partially)
     */
    public boolean hasReceivedPayment() {
        return paymentStatus.isPaid();
    }
    
    /**
     * Get outstanding amount (submitted - paid)
     * @return Outstanding amount that has not been paid
     */
    public BigDecimal getOutstandingAmount() {
        return totalSubmittedAmount.subtract(totalPaidAmount);
    }
    
    /**
     * Get rejection rate percentage
     * @return Percentage of claim amount that has been rejected (0-100)
     */
    public BigDecimal getRejectionRatePercentage() {
        if (totalSubmittedAmount == null || totalSubmittedAmount.compareTo(BigDecimal.ZERO) == 0) {
            return BigDecimal.ZERO;
        }
        return totalRejectedAmount.divide(totalSubmittedAmount, 4, BigDecimal.ROUND_HALF_UP)
                .multiply(BigDecimal.valueOf(100));
    }
    
    /**
     * Check if claim has been resubmitted
     * @return true if claim has been resubmitted
     */
    public boolean hasBeenResubmitted() {
        return resubmissionCount != null && resubmissionCount > 0;
    }
    
    /**
     * Check if claim has multiple remittances
     * @return true if claim has multiple remittances
     */
    public boolean hasMultipleRemittances() {
        return remittanceCount != null && remittanceCount > 1;
    }
    
    /**
     * Get average days per processing cycle
     * @return Average days per cycle, or null if not calculable
     */
    public Integer getAverageDaysPerCycle() {
        if (processingCycles == null || processingCycles <= 1 || daysToFinalSettlement == null) {
            return null;
        }
        return daysToFinalSettlement / processingCycles;
    }
    
    @Override
    public String toString() {
        return "ClaimPayment{" +
                "id=" + id +
                ", claimKey=" + (claimKey != null ? claimKey.getClaimId() : null) +
                ", paymentStatus=" + paymentStatus +
                ", totalSubmittedAmount=" + totalSubmittedAmount +
                ", totalPaidAmount=" + totalPaidAmount +
                ", remittanceCount=" + remittanceCount +
                ", resubmissionCount=" + resubmissionCount +
                '}';
    }
}
