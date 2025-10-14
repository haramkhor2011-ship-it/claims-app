// FILE: src/main/java/com/acme/claims/domain/RemittanceActivity.java
// Version: v2.0.0
// Maps: claims.remittance_activity
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name="remittance_activity", schema="claims",
        indexes=@Index(name="idx_remit_act_claim", columnList="remittance_claim_id"),
        uniqueConstraints=@UniqueConstraint(name="uq_remittance_activity", columnNames={"remittance_claim_id","activity_id"}))
public class RemittanceActivity {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="remittance_claim_id", nullable=false)
    private RemittanceClaim remittanceClaim;
    @Column(name="activity_id", nullable=false) private String activityId;
    @Column(name="start_at", nullable=false) private OffsetDateTime startAt;
    @Column(name="type", nullable=false) private String type;
    @Column(name="code", nullable=false) private String code;
    @Column(name="quantity", nullable=false, precision=14, scale=2) private BigDecimal quantity;
    @Column(name="net", nullable=false, precision=14, scale=2) private BigDecimal net;
    @Column(name="list_price", precision=14, scale=2) private BigDecimal listPrice;
    @Column(name="clinician", nullable=false) private String clinician;
    @Column(name="prior_authorization_id") private String priorAuthorizationId;
    @Column(name="gross", precision=14, scale=2) private BigDecimal gross;
    @Column(name="patient_share", precision=14, scale=2) private BigDecimal patientShare;
    @Column(name="payment_amount", nullable=false, precision=14, scale=2) private BigDecimal paymentAmount;
    @Column(name="denial_code") private String denialCode;
    @Column(name="denial_code_ref_id") private Long denialCodeRefId;
    @Column(name="activity_code_ref_id") private Long activityCodeRefId;
    @Column(name="clinician_ref_id") private Long clinicianRefId;
    @Column(name="created_at", nullable=false) private OffsetDateTime createdAt = OffsetDateTime.now();
    // getters/setters…
    public Long getId(){return id;} public void setId(Long id){this.id=id;}
    public RemittanceClaim getRemittanceClaim(){return remittanceClaim;}
    public void setRemittanceClaim(RemittanceClaim v){this.remittanceClaim=v;}
    public String getActivityId(){return activityId;} public void setActivityId(String v){this.activityId=v;}
    public OffsetDateTime getStartAt(){return startAt;} public void setStartAt(OffsetDateTime v){this.startAt=v;}
    public String getType(){return type;} public void setType(String v){this.type=v;}
    public String getCode(){return code;} public void setCode(String v){this.code=v;}
    public BigDecimal getQuantity(){return quantity;} public void setQuantity(BigDecimal v){this.quantity=v;}
    public BigDecimal getNet(){return net;} public void setNet(BigDecimal v){this.net=v;}
    public BigDecimal getListPrice(){return listPrice;} public void setListPrice(BigDecimal v){this.listPrice=v;}
    public String getClinician(){return clinician;} public void setClinician(String v){this.clinician=v;}
    public String getPriorAuthorizationId(){return priorAuthorizationId;} public void setPriorAuthorizationId(String v){this.priorAuthorizationId=v;}
    public BigDecimal getGross(){return gross;} public void setGross(BigDecimal v){this.gross=v;}
    public BigDecimal getPatientShare(){return patientShare;} public void setPatientShare(BigDecimal v){this.patientShare=v;}
    public BigDecimal getPaymentAmount(){return paymentAmount;} public void setPaymentAmount(BigDecimal v){this.paymentAmount=v;}
    public String getDenialCode(){return denialCode;} public void setDenialCode(String v){this.denialCode=v;}
    public Long getDenialCodeRefId(){return denialCodeRefId;} public void setDenialCodeRefId(Long v){this.denialCodeRefId=v;}
    public Long getActivityCodeRefId(){return activityCodeRefId;} public void setActivityCodeRefId(Long v){this.activityCodeRefId=v;}
    public Long getClinicianRefId(){return clinicianRefId;} public void setClinicianRefId(Long v){this.clinicianRefId=v;}
    public OffsetDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(OffsetDateTime v){this.createdAt=v;}
}
