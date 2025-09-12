/*
 * SSOT NOTICE — File Archiver (Best-effort)
 * Purpose: Move original input files to archive/ok or archive/fail when stageToDisk=true.
 * Notes:
 *   - The Pipeline already guards moves with the stageToDisk switch and sourcePath presence.
 *   - This utility centralizes move logic if you prefer to call here instead of inline.
 */
package com.acme.claims.ingestion.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.file.Files;
import java.nio.file.Path;

public final class FileArchiver {

    private static final Logger log = LoggerFactory.getLogger(FileArchiver.class);

    private FileArchiver() {}

    /** Move the file to the ok archive directory (best-effort). */
    public static void archiveOk(Path source, Path okDir, String fileId) {
        move(source, okDir, fileId);
    }

    /** Move the file to the fail archive directory (best-effort). */
    public static void archiveFail(Path source, Path failDir, String fileId) {
        move(source, failDir, fileId);
    }

    private static void move(Path source, Path targetDir, String fileId) {
        if (source == null || targetDir == null || fileId == null) return;
        try {
            Files.createDirectories(targetDir);
            Files.move(source, targetDir.resolve(fileId), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        } catch (Exception e) {
            log.warn("Archive move failed for {} -> {} : {}", source, targetDir, e.getMessage());
        }
    }
}
