package com.acme.claims.mapper;

import com.acme.claims.domain.model.dto.AttachmentDTO;
import com.acme.claims.domain.model.entity.ClaimAttachment;
import org.mapstruct.*;

@Mapper(componentModel = "spring", config = MapStructCentralConfig.class)
public interface ClaimAttachmentMapper {

    @Mapping(target="id", ignore=true)
    @Mapping(target="createdAt", expression="java(java.time.OffsetDateTime.now())")
    @Mapping(target="dataBase64", expression="java(dto.decode())")
    ClaimAttachment toEntity(AttachmentDTO dto,
                             Long claimKeyId,
                             Long claimEventId);

    @InheritInverseConfiguration
    @Mapping(target="base64Data", expression="java(java.util.Base64.getEncoder().encodeToString(entity.getDataBase64()))")
    AttachmentDTO toDto(ClaimAttachment entity);
}
