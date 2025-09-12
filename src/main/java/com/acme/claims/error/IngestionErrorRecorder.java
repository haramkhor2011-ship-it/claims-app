// FILE: src/main/java/com/acme/claims/ingestion/error/IngestionErrorRecorder.java
// Version: v1.0.0
package com.acme.claims.error;


import com.acme.claims.domain.model.entity.IngestionFile;

public interface IngestionErrorRecorder {
    void recordParseError(IngestionFile file, String objectType, String objectKey, String errorCode, String message, String stackExcerpt);
}
