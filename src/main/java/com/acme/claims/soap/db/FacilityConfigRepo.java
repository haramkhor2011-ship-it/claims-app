// src/main/java/com/acme/claims/soap/db/FacilityConfigRepo.java
package com.acme.claims.soap.db;

import lombok.Builder;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.DataClassRowMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
@RequiredArgsConstructor
public class FacilityConfigRepo {
    private final JdbcTemplate jdbc;

    public List<Facility> findActive() {
        return jdbc.query("""
      select facility_id, facility_code, facility_name, active,
             endpoint_url, soap_version_12, caller_license, e_partner,
             last_polled_at, last_success_at, last_error_code, breaker_open_until
        from claims.facility_dhpo_config
       where active = true
       order by facility_code
      """, new DataClassRowMapper<>(Facility.class));
    }

    @Builder
    public record Facility(
            Long facilityId,
            String facilityCode,
            String facilityName,
            Boolean active,
            String endpointUrl,
            Boolean soapVersion12,
            String callerLicense,
            String ePartner,
            String loginCt,
            String pwdCt,
            java.time.OffsetDateTime lastPolledAt,
            java.time.OffsetDateTime lastSuccessAt,
            Integer lastErrorCode,
            java.time.OffsetDateTime breakerOpenUntil
    ) {}
}
