// FILE: src/main/java/com/acme/claims/domain/ClaimEventActivity.java
// Version: v2.0.0
// Maps: claims.claim_event_activity
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name="claim_event_activity", schema="claims",
        indexes=@Index(name="idx_cea_event", columnList="claim_event_id"))
public class ClaimEventActivity {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="claim_event_id", nullable=false)
    private ClaimEvent claimEvent;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="activity_id_ref")
    private Activity activityRef;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="remittance_activity_id_ref")
    private RemittanceActivity remittanceActivityRef;

    @Column(name="activity_id_at_event", nullable=false) private String activityIdAtEvent;
    @Column(name="start_at_event", nullable=false) private OffsetDateTime startAtEvent;
    @Column(name="type_at_event", nullable=false) private String typeAtEvent;
    @Column(name="code_at_event", nullable=false) private String codeAtEvent;
    @Column(name="quantity_at_event", nullable=false, precision=14, scale=2) private BigDecimal quantityAtEvent;
    @Column(name="net_at_event", nullable=false, precision=14, scale=2) private BigDecimal netAtEvent;
    @Column(name="clinician_at_event", nullable=false) private String clinicianAtEvent;
    @Column(name="prior_authorization_id_at_event") private String priorAuthorizationIdAtEvent;

    @Column(name="list_price_at_event", precision=14, scale=2) private BigDecimal listPriceAtEvent;
    @Column(name="gross_at_event", precision=14, scale=2) private BigDecimal grossAtEvent;
    @Column(name="patient_share_at_event", precision=14, scale=2) private BigDecimal patientShareAtEvent;
    @Column(name="payment_amount_at_event", precision=14, scale=2) private BigDecimal paymentAmountAtEvent;
    @Column(name="denial_code_at_event") private String denialCodeAtEvent;
    @Column(name="created_at", nullable=false) private OffsetDateTime createdAt = OffsetDateTime.now();
    // getters/setters…
    public Long getId(){return id;} public void setId(Long id){this.id=id;}
    public ClaimEvent getClaimEvent(){return claimEvent;} public void setClaimEvent(ClaimEvent v){this.claimEvent=v;}
    public Activity getActivityRef(){return activityRef;} public void setActivityRef(Activity v){this.activityRef=v;}
    public RemittanceActivity getRemittanceActivityRef(){return remittanceActivityRef;}
    public void setRemittanceActivityRef(RemittanceActivity v){this.remittanceActivityRef=v;}
    public String getActivityIdAtEvent(){return activityIdAtEvent;} public void setActivityIdAtEvent(String v){this.activityIdAtEvent=v;}
    public OffsetDateTime getStartAtEvent(){return startAtEvent;} public void setStartAtEvent(OffsetDateTime v){this.startAtEvent=v;}
    public String getTypeAtEvent(){return typeAtEvent;} public void setTypeAtEvent(String v){this.typeAtEvent=v;}
    public String getCodeAtEvent(){return codeAtEvent;} public void setCodeAtEvent(String v){this.codeAtEvent=v;}
    public BigDecimal getQuantityAtEvent(){return quantityAtEvent;} public void setQuantityAtEvent(BigDecimal v){this.quantityAtEvent=v;}
    public BigDecimal getNetAtEvent(){return netAtEvent;} public void setNetAtEvent(BigDecimal v){this.netAtEvent=v;}
    public String getClinicianAtEvent(){return clinicianAtEvent;} public void setClinicianAtEvent(String v){this.clinicianAtEvent=v;}
    public String getPriorAuthorizationIdAtEvent(){return priorAuthorizationIdAtEvent;}
    public void setPriorAuthorizationIdAtEvent(String v){this.priorAuthorizationIdAtEvent=v;}
    public BigDecimal getListPriceAtEvent(){return listPriceAtEvent;} public void setListPriceAtEvent(BigDecimal v){this.listPriceAtEvent=v;}
    public BigDecimal getGrossAtEvent(){return grossAtEvent;} public void setGrossAtEvent(BigDecimal v){this.grossAtEvent=v;}
    public BigDecimal getPatientShareAtEvent(){return patientShareAtEvent;} public void setPatientShareAtEvent(BigDecimal v){this.patientShareAtEvent=v;}
    public BigDecimal getPaymentAmountAtEvent(){return paymentAmountAtEvent;} public void setPaymentAmountAtEvent(BigDecimal v){this.paymentAmountAtEvent=v;}
    public String getDenialCodeAtEvent(){return denialCodeAtEvent;} public void setDenialCodeAtEvent(String v){this.denialCodeAtEvent=v;}
    public OffsetDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(OffsetDateTime v){this.createdAt=v;}
}
