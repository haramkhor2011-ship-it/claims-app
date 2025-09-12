// src/main/java/com/acme/claims/fetch/SetownloadedHook.java
package com.acme.claims.soap.fetch;

import com.acme.claims.domain.repo.FacilityDhpoConfigRepo;
import com.acme.claims.security.ame.CredsCipherService;
import com.acme.claims.soap.SoapGateway;
import com.acme.claims.soap.db.ToggleRepo;
import com.acme.claims.soap.parse.SetDownloadedParser;
import com.acme.claims.soap.req.SetTransactionDownloadedRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@Profile("soap")
@RequiredArgsConstructor
public class SetDownloadedHook {

    private final SoapGateway gateway;
    private final FacilityDhpoConfigRepo facilities;
    private final ToggleRepo toggles;
    private final CredsCipherService creds;

    /**
     * Call from your Verify stage once the file is persisted and verified OK.
     * @param facilityCode which facility the file belongs to
     * @param fileId remote DHPO FileID (we store this alongside ingestion_file)
     */
    public void maybeMarkDownloaded(String facilityCode, String fileId) {
        if (!toggles.isEnabled("dhpo.setDownloaded.enabled")) {
            log.debug("SetDownloaded disabled; skipping for facility={} fileId={}", facilityCode, fileId);
            return;
        }
        var f = facilities.findByActiveTrue().stream()
                .filter(x -> x.getFacilityCode().equals(facilityCode)).findFirst()
                .orElse(null);
        if (f == null) {
            log.warn("SetDownloaded: no active facility for code={}", facilityCode);
            return;
        }
        try {
            var plain = creds.decryptFor(f);
            var req = SetTransactionDownloadedRequest.build(plain.login(), plain.pwd(), fileId, Boolean.FALSE);
            var resp = gateway.call(req);
            var parsed = new SetDownloadedParser().parse(resp.envelopeXml());
            if (parsed.code() > 0 || parsed.code() == 0) {
                log.info("SetDownloaded OK facility={} fileId={} code={}", facilityCode, fileId, parsed.code());
            } else {
                log.warn("SetDownloaded FAIL facility={} fileId={} code={} msg={}", facilityCode, fileId, parsed.code(), parsed.errorMessage());
            }
        } catch (Exception e) {
            log.error("SetDownloaded EX facility={} fileId={} : {}", facilityCode, fileId, e.toString());
        }
    }
}
