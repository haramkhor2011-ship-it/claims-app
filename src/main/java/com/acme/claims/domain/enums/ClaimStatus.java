// FILE: src/main/java/com/acme/claims/domain/enums/ClaimStatus.java
// Version: v2.0.0
package com.acme.claims.domain.enums;
public enum ClaimStatus {
    SUBMITTED(1), RESUBMITTED(2), PAID(3), PARTIALLY_PAID(4), REJECTED(5), UNKNOWN(6);
    private final int code; ClaimStatus(int c){this.code=c;} public int getCode(){return code;}
    public static ClaimStatus from(int c){ for(var v:values()) if(v.code==c) return v; throw new IllegalArgumentException("bad code:"+c);}
}
