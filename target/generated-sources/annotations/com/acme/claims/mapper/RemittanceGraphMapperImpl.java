package com.acme.claims.mapper;

import com.acme.claims.domain.model.dto.RemittanceActivityDTO;
import com.acme.claims.domain.model.dto.RemittanceAdviceDTO;
import com.acme.claims.domain.model.dto.RemittanceClaimDTO;
import com.acme.claims.domain.model.entity.ClaimKey;
import com.acme.claims.domain.model.entity.IngestionFile;
import com.acme.claims.domain.model.entity.Remittance;
import com.acme.claims.domain.model.entity.RemittanceActivity;
import com.acme.claims.domain.model.entity.RemittanceClaim;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2025-09-22T19:40:19+0530",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 21.0.8 (Microsoft)"
)
@Component
public class RemittanceGraphMapperImpl implements RemittanceGraphMapper {

    @Override
    public Remittance toRemittance(RemittanceAdviceDTO dto, IngestionFile file) {
        if ( dto == null && file == null ) {
            return null;
        }

        Remittance remittance = new Remittance();

        remittance.setIngestionFile( file );

        return remittance;
    }

    @Override
    public RemittanceClaim toRemittanceClaim(RemittanceClaimDTO dto, Remittance remittance, ClaimKey key) {
        if ( dto == null && remittance == null && key == null ) {
            return null;
        }

        RemittanceClaim remittanceClaim = new RemittanceClaim();

        if ( dto != null ) {
            remittanceClaim.setIdPayer( dto.idPayer() );
            remittanceClaim.setProviderId( dto.providerId() );
            remittanceClaim.setDenialCode( dto.denialCode() );
            remittanceClaim.setPaymentReference( dto.paymentReference() );
            remittanceClaim.setDateSettlement( dto.dateSettlement() );
            remittanceClaim.setFacilityId( dto.facilityId() );
        }
        remittanceClaim.setRemittance( remittance );
        remittanceClaim.setClaimKey( key );
        remittanceClaim.setCreatedAt( java.time.OffsetDateTime.now() );

        return remittanceClaim;
    }

    @Override
    public RemittanceActivity toRemittanceActivity(RemittanceActivityDTO dto, RemittanceClaim rc) {
        if ( dto == null && rc == null ) {
            return null;
        }

        RemittanceActivity remittanceActivity = new RemittanceActivity();

        if ( dto != null ) {
            remittanceActivity.setActivityId( dto.id() );
            remittanceActivity.setStartAt( dto.start() );
            remittanceActivity.setType( dto.type() );
            remittanceActivity.setCode( dto.code() );
            remittanceActivity.setQuantity( dto.quantity() );
            remittanceActivity.setNet( dto.net() );
            remittanceActivity.setListPrice( dto.listPrice() );
            remittanceActivity.setClinician( dto.clinician() );
            remittanceActivity.setPriorAuthorizationId( dto.priorAuthorizationId() );
            remittanceActivity.setGross( dto.gross() );
            remittanceActivity.setPatientShare( dto.patientShare() );
            remittanceActivity.setPaymentAmount( dto.paymentAmount() );
            remittanceActivity.setDenialCode( dto.denialCode() );
        }
        remittanceActivity.setRemittanceClaim( rc );
        remittanceActivity.setCreatedAt( java.time.OffsetDateTime.now() );

        return remittanceActivity;
    }
}
