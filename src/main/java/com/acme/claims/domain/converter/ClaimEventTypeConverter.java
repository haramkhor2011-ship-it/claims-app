// FILE: src/main/java/com/acme/claims/domain/converter/ClaimEventTypeConverter.java
// Version: v2.0.0
package com.acme.claims.domain.converter;

import com.acme.claims.domain.enums.ClaimEventType;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = true)
public class ClaimEventTypeConverter implements AttributeConverter<ClaimEventType, Short> {
    @Override public Short convertToDatabaseColumn(ClaimEventType a){ return a==null?null:(short)a.getCode(); }
    @Override public ClaimEventType convertToEntityAttribute(Short db){ return db==null?null:ClaimEventType.from(db); }
}
