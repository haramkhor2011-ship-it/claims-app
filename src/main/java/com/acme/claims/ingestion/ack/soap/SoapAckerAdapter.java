// src/main/java/com/acme/claims/ingestion/ack/soap/SoapAckerAdapter.java
package com.acme.claims.ingestion.ack.soap;

import com.acme.claims.ingestion.ack.Acker;
import com.acme.claims.soap.fetch.DhpoFileRegistry;
import com.acme.claims.soap.fetch.SetDownloadedHook;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * Best-effort ACK: delegates to your SOAP gateway hook (SetDownloaded/SetTransactionDownloaded).
 * Only fires when success==true AND ack toggle enabled.
 */
@Slf4j
@Component
@Profile("soap")
@RequiredArgsConstructor
public class SoapAckerAdapter implements Acker {

    private final SetDownloadedHook setDownloadedHook;
    private final DhpoFileRegistry fileRegistry;

    @Value("${claims.ack.enabled:true}")
    private boolean ackEnabled;

    @Override
    public void maybeAck(String fileId, boolean success) {
        if (!ackEnabled) {
            log.debug("SOAP_ACK_DISABLED fileId={}", fileId);
            return;
        }
        if (!success) {
            log.debug("SOAP_ACK_SKIPPED fileId={} reason=VERIFY_FAILED", fileId);
            return;
        }
        log.info("SOAP_ACK_START fileId={} success={}", fileId, success);
        try {
            log.debug("[SOAP] ACK → SetDownloaded for fileId={}", fileId);
            var facilityOpt = fileRegistry.facilityFor(fileId);
            if (facilityOpt.isEmpty()) {
                log.warn("SOAP_ACK_SKIPPED fileId={} reason=FACILITY_NOT_FOUND", fileId);
                return;
            }
            var facilityCode = facilityOpt.get();
            log.info("SOAP_ACK_CALLING fileId={} facility={}", fileId, facilityCode);
            // Method name per your class: maybeMarkDownloaded(facilityCode, fileId)
            setDownloadedHook.maybeMarkDownloaded(facilityCode, fileId);
            // best-effort cleanup
            fileRegistry.forget(fileId);
            log.info("SOAP_ACK_SUCCESS fileId={} facility={}", fileId, facilityCode);

        } catch (Exception e) {
            log.error("SOAP_ACK_FAILED fileId={} : {}", fileId, e.toString());
        } finally {
            fileRegistry.forget(fileId);
        }
    }
}
