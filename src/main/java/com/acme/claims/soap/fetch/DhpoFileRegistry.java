
package com.acme.claims.soap.fetch;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Bounded ephemeral map of fileId -> facilityCode for ACK.
 * Written by DhpoFetchCoordinator at download time, read by SoapAckerAdapter post-verify.
 */
@Component
@Profile("soap")
public class DhpoFileRegistry {
    private final Map<String, String> byFileId = new ConcurrentHashMap<>(4096);

    public void remember(String fileId, String facilityCode) {
        if (fileId != null && facilityCode != null) byFileId.put(fileId, facilityCode);
    }

    public Optional<String> facilityFor(String fileId) {
        return Optional.ofNullable(byFileId.get(fileId));
    }

    public void forget(String fileId) {
        if (fileId != null) byFileId.remove(fileId);
    }
}
