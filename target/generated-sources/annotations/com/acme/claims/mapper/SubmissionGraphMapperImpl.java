package com.acme.claims.mapper;

import com.acme.claims.domain.model.dto.ActivityDTO;
import com.acme.claims.domain.model.dto.DiagnosisDTO;
import com.acme.claims.domain.model.dto.EncounterDTO;
import com.acme.claims.domain.model.dto.ObservationDTO;
import com.acme.claims.domain.model.dto.SubmissionClaimDTO;
import com.acme.claims.domain.model.dto.SubmissionDTO;
import com.acme.claims.domain.model.entity.Activity;
import com.acme.claims.domain.model.entity.Claim;
import com.acme.claims.domain.model.entity.ClaimKey;
import com.acme.claims.domain.model.entity.Diagnosis;
import com.acme.claims.domain.model.entity.Encounter;
import com.acme.claims.domain.model.entity.IngestionFile;
import com.acme.claims.domain.model.entity.Observation;
import com.acme.claims.domain.model.entity.Submission;
import java.util.Arrays;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2025-09-11T21:48:07+0530",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 21.0.8 (Microsoft)"
)
@Component
public class SubmissionGraphMapperImpl implements SubmissionGraphMapper {

    @Override
    public Submission toSubmission(SubmissionDTO dto, IngestionFile file) {
        if ( dto == null && file == null ) {
            return null;
        }

        Submission submission = new Submission();

        submission.setIngestionFile( file );

        return submission;
    }

    @Override
    public Claim toClaim(SubmissionClaimDTO dto, ClaimKey key, Submission submission) {
        if ( dto == null && key == null && submission == null ) {
            return null;
        }

        Claim claim = new Claim();

        if ( dto != null ) {
            claim.setIdPayer( dto.idPayer() );
            claim.setMemberId( dto.memberId() );
            claim.setPayerId( dto.payerId() );
            claim.setProviderId( dto.providerId() );
            claim.setEmiratesIdNumber( dto.emiratesIdNumber() );
            claim.setGross( dto.gross() );
            claim.setPatientShare( dto.patientShare() );
            claim.setNet( dto.net() );
            claim.setComments( dto.comments() );
        }
        claim.setClaimKey( key );
        claim.setSubmission( submission );

        return claim;
    }

    @Override
    public Encounter toEncounter(EncounterDTO dto, Claim claim) {
        if ( dto == null && claim == null ) {
            return null;
        }

        Encounter encounter = new Encounter();

        if ( dto != null ) {
            encounter.setFacilityId( dto.facilityId() );
            encounter.setType( dto.type() );
            encounter.setPatientId( dto.patientId() );
            encounter.setStartAt( dto.start() );
            encounter.setEndAt( dto.end() );
            encounter.setStartType( dto.startType() );
            encounter.setEndType( dto.endType() );
            encounter.setTransferSource( dto.transferSource() );
            encounter.setTransferDestination( dto.transferDestination() );
        }
        encounter.setClaim( claim );

        return encounter;
    }

    @Override
    public Diagnosis toDiagnosis(DiagnosisDTO dto, Claim claim) {
        if ( dto == null && claim == null ) {
            return null;
        }

        Diagnosis diagnosis = new Diagnosis();

        if ( dto != null ) {
            diagnosis.setDiagType( dto.type() );
            diagnosis.setCode( dto.code() );
        }
        diagnosis.setClaim( claim );

        return diagnosis;
    }

    @Override
    public Activity toActivity(ActivityDTO dto, Claim claim) {
        if ( dto == null && claim == null ) {
            return null;
        }

        Activity activity = new Activity();

        if ( dto != null ) {
            activity.setActivityId( dto.id() );
            activity.setStartAt( dto.start() );
            activity.setType( dto.type() );
            activity.setCode( dto.code() );
            activity.setQuantity( dto.quantity() );
            activity.setNet( dto.net() );
            activity.setClinician( dto.clinician() );
            activity.setPriorAuthorizationId( dto.priorAuthorizationId() );
        }
        activity.setClaim( claim );
        activity.setCreatedAt( java.time.OffsetDateTime.now() );
        activity.setUpdatedAt( java.time.OffsetDateTime.now() );

        return activity;
    }

    @Override
    public Observation toObservation(ObservationDTO dto, Activity activity) {
        if ( dto == null && activity == null ) {
            return null;
        }

        Observation observation = new Observation();

        if ( dto != null ) {
            observation.setObsType( dto.type() );
            observation.setObsCode( dto.code() );
            observation.setValueText( dto.value() );
            observation.setValueType( dto.valueType() );
            byte[] fileBytes = dto.fileBytes();
            if ( fileBytes != null ) {
                observation.setFileBytes( Arrays.copyOf( fileBytes, fileBytes.length ) );
            }
        }
        observation.setActivity( activity );

        return observation;
    }
}
