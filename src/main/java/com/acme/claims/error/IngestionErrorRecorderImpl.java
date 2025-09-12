// FILE: src/main/java/com/acme/claims/ingestion/error/IngestionErrorRecorderImpl.java
// Version: v1.0.0
package com.acme.claims.error;


import com.acme.claims.domain.model.entity.IngestionError;
import com.acme.claims.domain.model.entity.IngestionFile;
import com.acme.claims.domain.repo.IngestionErrorRepository;
import org.springframework.stereotype.Service;

@Service
public class IngestionErrorRecorderImpl implements IngestionErrorRecorder {
    private final IngestionErrorRepository repo;
    public IngestionErrorRecorderImpl(IngestionErrorRepository repo){ this.repo = repo; }

    @Override
    public void recordParseError(IngestionFile file, String objectType, String objectKey, String errorCode, String message, String stackExcerpt) {
        IngestionError e = new IngestionError();
        e.setIngestionFile(file);
        e.setStage("PARSE");                  // stage taxonomy
        e.setObjectType(objectType);          // e.g., "HEADER" | "CLAIM" | "ACTIVITY"
        e.setObjectKey(objectKey);            // e.g., claimId or activityId
        e.setErrorCode(errorCode);            // e.g., "XSD_MISSING_FIELD"
        e.setErrorMessage(message);
        e.setStackExcerpt(stackExcerpt);
        e.setRetryable(false);                // parse errors are not retryable
        repo.save(e);
    }
}
