package com.acme.claims.soap.fetch.exception;

/**
 * Exception thrown when file staging operations fail.
 */
public class DhpoStagingException extends DhpoFetchException {
    private final String fileId;
    private final String stagingMode;

    public DhpoStagingException(String facilityCode, String fileId, String stagingMode, String message) {
        super(facilityCode, "FILE_STAGING", "STAGING_ERROR", message);
        this.fileId = fileId;
        this.stagingMode = stagingMode;
    }

    public DhpoStagingException(String facilityCode, String fileId, String stagingMode, String message, Throwable cause) {
        super(facilityCode, "FILE_STAGING", "STAGING_ERROR", message, cause);
        this.fileId = fileId;
        this.stagingMode = stagingMode;
    }

    public String getFileId() {
        return fileId;
    }

    public String getStagingMode() {
        return stagingMode;
    }
}
