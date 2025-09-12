/*
 * SSOT NOTICE — Work Item (Ingestion Unit)
 * Purpose: Immutable unit of work representing one XML file (either fetched from disk or SOAP),
 *          processed in-memory by the pipeline.
 * Notes:
 *   - fileId: stable identifier (e.g., filename or remote message id) — used for idempotency and audit.
 *   - xmlBytes: the raw XML payload (we parse directly from memory; no temp file needed).
 *   - sourcePath: present only when LocalFS profile is used and stageToDisk=true (for archiving).
 *   - source: simple tag like "localfs" or "soap" for audit/metrics dimensions.
 */
package com.acme.claims.ingestion.fetch;

import java.nio.file.Path;

public record WorkItem(
        String fileId,   // business-stable id for the file; used to upsert ingestion_file and for ACK
        byte[] xmlBytes, // raw XML payload; parser reads from this directly (StAX over InputStream)
        Path sourcePath, // non-null only when coming from LocalFS and we plan to archive/move
        String source    // "localfs" or "soap" for tagging in logs/metrics
) {}
