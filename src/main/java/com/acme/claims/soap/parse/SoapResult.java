package com.acme.claims.soap.parse;

import java.util.List;

public record SoapResult(
        int code,                // DHPO result code (0 OK, -4 transient, etc.)
        String errorMessage,     // optional
        String xmlPayload,       // e.g., xmlTransaction or foundTransactions
        List<SoapTxMeta> metas   // optional parsed rows (fileId, fileName, isDownloaded)
) {
    public boolean okOrNoData() { return code >= 0 || code == 2; } // 0 OK; 2 "no new" (per DHPO)
    public boolean shouldRetryTransient() { return code == -4; }   // DHPO transient error. :contentReference[oaicite:9]{index=9}
}
