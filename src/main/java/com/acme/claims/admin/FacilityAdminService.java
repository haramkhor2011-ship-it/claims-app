package com.acme.claims.admin;

import com.acme.claims.security.ame.CredsCipherService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Slf4j
@Service
@RequiredArgsConstructor
@Profile("soap")
public class FacilityAdminService {

    private final JdbcTemplate jdbc;
    private final CredsCipherService cipher;

    @Transactional
    public void upsert(FacilityDto dto) {
        validate(dto);
        var c = cipher.encrypt(dto.facilityCode(), dto.login(), dto.password());
        log.info("Addind new Facility : {}", dto.facilityCode());
        jdbc.update("""
                          insert into claims.facility_dhpo_config
                            (facility_code, facility_name,dhpo_username_enc, dhpo_password_enc, enc_meta_json)
                          values (?,?,?,?,?::jsonb)
                          on conflict (facility_code) do update set
                            facility_name=excluded.facility_name,
                            dhpo_username_enc=excluded.dhpo_username_enc,
                            dhpo_password_enc=excluded.dhpo_password_enc,
                            enc_meta_json=excluded.enc_meta_json
                        """,
                dto.facilityCode(), dto.facilityName(), c.loginCt(), c.pwdCt(), c.encMetaJson()
        );
    }

    public FacilityView get(String facilityCode) {
        var f = jdbc.query("""
                          select facility_code, facility_name from claims.facility_dhpo_config where facility_code=?
                        """, ps -> ps.setString(1, facilityCode),
                rs -> rs.next() ? new FacilityView(
                        rs.getString(1), rs.getString(2), "******" // never return password
                ) : null);
        if (f == null) throw new IllegalArgumentException("Facility not found");
        return f;
    }

    public void activate(String code, boolean active) {
        jdbc.update("update claims.facility_dhpo_config set active=? where facility_code=?", active, code);
    }

    private static void validate(FacilityDto d) {
        if (!StringUtils.hasText(d.facilityCode())) throw new IllegalArgumentException("facilityCode required");
        if (!StringUtils.hasText(d.facilityName())) throw new IllegalArgumentException("facilityName required");
        if (!StringUtils.hasText(d.login())) throw new IllegalArgumentException("login required");
        if (!StringUtils.hasText(d.password())) throw new IllegalArgumentException("password required");
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }

    public record FacilityDto(String facilityCode, String facilityName, String login, String password) {
    }

    public record FacilityView(String facilityCode, String facilityName, String passwordMasked) {
    }
}
