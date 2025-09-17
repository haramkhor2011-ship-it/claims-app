package com.acme.claims.mapper;

import com.acme.claims.domain.model.dto.ResubmissionDTO;
import com.acme.claims.domain.model.entity.ClaimEvent;
import com.acme.claims.domain.model.entity.ClaimResubmission;
import java.util.Arrays;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2025-09-17T13:40:38+0000",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 21.0.7 (Ubuntu)"
)
@Component
public class ResubmissionEventMapperImpl implements ResubmissionEventMapper {

    @Override
    public ClaimResubmission toEntity(ResubmissionDTO dto, ClaimEvent event) {
        if ( dto == null && event == null ) {
            return null;
        }

        ClaimResubmission claimResubmission = new ClaimResubmission();

        if ( dto != null ) {
            claimResubmission.setResubmissionType( dto.type() );
            claimResubmission.setComment( dto.comment() );
            byte[] attachment = dto.attachment();
            if ( attachment != null ) {
                claimResubmission.setAttachment( Arrays.copyOf( attachment, attachment.length ) );
            }
        }
        claimResubmission.setClaimEvent( event );

        return claimResubmission;
    }
}
