package com.acme.claims.mapper;

import com.acme.claims.domain.model.dto.AttachmentDTO;
import com.acme.claims.domain.model.entity.ClaimAttachment;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2025-09-17T14:07:11+0000",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 21.0.7 (Ubuntu)"
)
@Component
public class ClaimAttachmentMapperImpl implements ClaimAttachmentMapper {

    @Override
    public ClaimAttachment toEntity(AttachmentDTO dto, Long claimKeyId, Long claimEventId) {
        if ( dto == null && claimKeyId == null && claimEventId == null ) {
            return null;
        }

        ClaimAttachment claimAttachment = new ClaimAttachment();

        if ( dto != null ) {
            claimAttachment.setFileName( dto.fileName() );
            claimAttachment.setMimeType( dto.mimeType() );
        }
        claimAttachment.setClaimKeyId( claimKeyId );
        claimAttachment.setClaimEventId( claimEventId );
        claimAttachment.setCreatedAt( java.time.OffsetDateTime.now() );
        claimAttachment.setDataBase64( dto.decode() );

        return claimAttachment;
    }

    @Override
    public AttachmentDTO toDto(ClaimAttachment entity) {
        if ( entity == null ) {
            return null;
        }

        String fileName = null;
        String mimeType = null;

        fileName = entity.getFileName();
        mimeType = entity.getMimeType();

        String base64Data = java.util.Base64.getEncoder().encodeToString(entity.getDataBase64());

        AttachmentDTO attachmentDTO = new AttachmentDTO( fileName, mimeType, base64Data );

        return attachmentDTO;
    }
}
