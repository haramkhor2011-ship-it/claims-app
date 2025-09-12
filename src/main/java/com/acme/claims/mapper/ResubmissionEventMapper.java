// FILE: src/main/java/com/acme/claims/ingestion/mapper/ResubmissionEventMapper.java
// Version: v1.0.0
package com.acme.claims.mapper;


import com.acme.claims.domain.model.dto.ResubmissionDTO;
import com.acme.claims.domain.model.entity.ClaimEvent;
import com.acme.claims.domain.model.entity.ClaimResubmission;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(config = MapStructCentralConfig.class)
public interface ResubmissionEventMapper {
    @Mapping(target="id", ignore = true)
    @Mapping(target="claimEvent", source="event")
    @Mapping(target="resubmissionType", source="dto.type")
    @Mapping(target="comment", source="dto.comment")
    @Mapping(target="attachment", source="dto.attachment") // byte[] -> byte[]
    ClaimResubmission toEntity(ResubmissionDTO dto, ClaimEvent event);
}
