// FILE: src/main/java/com/acme/claims/domain/converter/ClaimStatusConverter.java
// Version: v2.0.0
package com.acme.claims.domain.converter;

import com.acme.claims.domain.enums.ClaimStatus;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = true)
public class ClaimStatusConverter implements AttributeConverter<ClaimStatus, Short> {
    @Override public Short convertToDatabaseColumn(ClaimStatus a){ return a==null?null:(short)a.getCode(); }
    @Override public ClaimStatus convertToEntityAttribute(Short db){ return db==null?null:ClaimStatus.from(db); }
}
