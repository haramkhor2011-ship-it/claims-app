// FILE: src/main/java/com/acme/claims/domain/enums/ClaimEventType.java
// Version: v2.0.0
package com.acme.claims.domain.enums;
public enum ClaimEventType { SUBMISSION(1), RESUBMISSION(2), REMITTANCE(3);
    private final int code; ClaimEventType(int c){this.code=c;} public int getCode(){return code;}
    public static ClaimEventType from(int c){ for(var v:values()) if(v.code==c) return v; throw new IllegalArgumentException("bad code:"+c);}
}
