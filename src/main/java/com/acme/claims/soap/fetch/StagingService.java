// src/main/java/com/acme/claims/fetch/StagingService.java
package com.acme.claims.soap.fetch;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

import java.nio.file.*;
import java.security.MessageDigest;
import java.util.HexFormat;

@Slf4j
@Service
@RequiredArgsConstructor
@Profile("soap")
public class StagingService {

    public enum Mode { MEM, DISK }

    public record Staged(Mode mode, String fileId, byte[] bytes, Path path) {}

    public Staged decideAndStage(byte[] bytes, String serverFileName, long downloadLatencyMs, StagingPolicy pol) throws Exception {
        boolean toDisk = pol.forceDisk()
                || bytes.length >= pol.sizeThresholdBytes()
                || downloadLatencyMs >= pol.latencyThresholdMs();
        String fileId = safeName(serverFileName);
        if (fileId == null) fileId = sha256Name(bytes);

        if (!toDisk) {
            return new Staged(Mode.MEM, fileId, bytes, null);
        }
        Path readyDir = Paths.get(pol.readyDir());
        Files.createDirectories(readyDir);
        Path tmp = readyDir.resolve(fileId + ".tmp");
        Path fin = readyDir.resolve(fileId);
        Files.write(tmp, bytes, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
        Files.move(tmp, fin, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        log.info("Staged to disk: {} ({} bytes)", fin.getFileName(), bytes.length);
        return new Staged(Mode.DISK, fileId, null, fin);
    }

    private static String safeName(String name) {
        if (name==null) return null;
        String n = name.trim();
        if (n.isBlank()) return null;
        if (!n.toLowerCase().endsWith(".xml")) return null;
        if (n.contains("/")||n.contains("\\")||n.contains("..")) return null;
        return n;
    }
    private static String sha256Name(byte[] bytes) throws Exception {
        var md = MessageDigest.getInstance("SHA-256");
        md.update(bytes);
        return HexFormat.of().formatHex(md.digest()) + ".xml";
    }
}
