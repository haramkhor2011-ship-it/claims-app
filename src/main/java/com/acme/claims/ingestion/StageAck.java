// src/main/java/com/acme/claims/ingestion/StageAck.java
package com.acme.claims.ingestion;

import com.acme.claims.ingestion.ack.Acker;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

/** Pipeline stage that conditionally ACKs based on verify result. */
@Slf4j
@Service
@Profile("ingestion")
@RequiredArgsConstructor
public class StageAck {

    private final Acker acker;

    /** @param success true when verify passed; false to skip ACK. */
    public void maybeAck(String fileId, boolean success, String  facilityCode) {
        acker.maybeAck(fileId, success); // delegate to active profile-specific acker
    }
}
