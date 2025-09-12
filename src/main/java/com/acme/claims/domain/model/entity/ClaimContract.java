// FILE: src/main/java/com/acme/claims/domain/ClaimContract.java
// Version: v2.0.0
// Maps: claims.claim_contract
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;

@Entity @Table(name="claim_contract", schema="claims")
public class ClaimContract {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="claim_id", nullable=false)
    private Claim claim;
    @Column(name="package_name") private String packageName;
    // getters/setters
    public Long getId(){return id;} public void setId(Long id){this.id=id;}
    public Claim getClaim(){return claim;} public void setClaim(Claim v){this.claim=v;}
    public String getPackageName(){return packageName;} public void setPackageName(String v){this.packageName=v;}
}
