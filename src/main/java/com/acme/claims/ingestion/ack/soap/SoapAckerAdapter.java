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
@Profile({"ingestion", "soap"})
@RequiredArgsConstructor
public class SoapAckerAdapter implements Acker {

    private final SetDownloadedHook setDownloadedHook;
    private final DhpoFileRegistry fileRegistry;

    @Value("${claims.ack.enabled:true}")
    private boolean ackEnabled;

    @Override
    public void maybeAck(String fileId, boolean success) {
        if (!ackEnabled) {
            log.debug("[SOAP] ACK disabled; skip fileId={}", fileId);
            return;
        }
        if (!success) {
            log.debug("[SOAP] Verify not green; skip ACK for fileId={}", fileId);
            return;
        }
        try {
            log.debug("[SOAP] ACK → SetDownloaded for fileId={}", fileId);
            var facilityOpt = fileRegistry.facilityFor(fileId);
            if (facilityOpt.isEmpty()) {
                log.warn("[SOAP] ACK skipped: facility not found for fileId={}", fileId);
                return;
            }
            var facilityCode = facilityOpt.get();
            log.debug("[SOAP] ACK → SetDownloaded facility={} fileId={}", facilityCode, fileId);
            // Method name per your class: maybeMarkDownloaded(facilityCode, fileId)
            setDownloadedHook.maybeMarkDownloaded(facilityCode, fileId);
            // best-effort cleanup
            fileRegistry.forget(fileId);
            log.debug("[SOAP] ACK success for fileId={}", fileId);

        } catch (Exception e) {
            log.warn("[SOAP] ACK failed for fileId={} : {}", fileId, e.toString());
        } finally {
            fileRegistry.forget(fileId);
        }
    }
}
