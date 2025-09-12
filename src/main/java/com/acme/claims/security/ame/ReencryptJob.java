// src/main/java/com/acme/claims/security/ame/ReencryptJob.java
package com.acme.claims.security.ame;

import com.acme.claims.domain.model.entity.FacilityDhpoConfig;
import com.acme.claims.domain.repo.FacilityDhpoConfigRepo;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@Profile("soap")
@RequiredArgsConstructor
public class ReencryptJob {

    private final FacilityDhpoConfigRepo repo;
    private final CredsCipherService cipher;
    private final JdbcTemplate jdbc;
    private final AmeProperties props;

    /**
     * Run from an admin-only endpoint after rotating the KEK (keyId).
     * Re-encrypts all rows whose enc_meta_json.keyId != current keyId.
     */
    public int reencryptAllIfNeeded() {
        var all = repo.findAll();
        int changed = 0;
        String targetKeyId = props.crypto().keyId();

        for (FacilityDhpoConfig f : all) {
            byte[] userCt = f.getDhpoUsernameEnc();
            byte[] pwdCt  = f.getDhpoPasswordEnc();
            String meta   = f.getEncMetaJson();
            if (userCt == null || pwdCt == null || isBlank(meta)) {
                continue; // nothing to migrate
            }

            var metaObj = safeMeta(meta);
            String rowKeyId = metaObj.optString("keyId", "");
            if (targetKeyId.equals(rowKeyId)) {
                continue; // already on latest key
            }

            try {
                // decrypt with old key/meta
                String login = cipher.decryptUsername(userCt, meta, f.getFacilityCode());
                String pwd   = cipher.decryptPassword(pwdCt,  meta, f.getFacilityCode());

                // encrypt with current key/meta (split IVs)
                var c = cipher.encrypt(f.getFacilityCode(), login, pwd);

                // persist using exact column names
                int updated = jdbc.update("""
                    UPDATE claims.facility_dhpo_config
                       SET dhpo_username_enc = ?,
                           dhpo_password_enc = ?,
                           enc_meta_json     = ?,
                           updated_at        = now()
                     WHERE facility_code    = ?
                """, c.loginCt(), c.pwdCt(), c.encMetaJson(), f.getFacilityCode());

                if (updated == 1) changed++;
                else log.warn("Reencrypt: no row updated for facility_code={}", f.getFacilityCode());
            } catch (Exception e) {
                log.error("Reencrypt failed for facility_code={} : {}", f.getFacilityCode(), e.toString());
            }
        }
        log.info("Reencrypt complete; rows updated={}", changed);
        return changed;
    }

    private static JSONObject safeMeta(String json) {
        try { return new JSONObject(json); } catch (Exception e) { return new JSONObject(); }
    }
    private static boolean isBlank(String s){ return s == null || s.isBlank(); }
}
