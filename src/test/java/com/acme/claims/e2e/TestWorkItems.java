package com.acme.claims.e2e;

import com.acme.claims.ingestion.fetch.WorkItem;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Path;

public final class TestWorkItems {
    private TestWorkItems(){}

    public static WorkItem fromResource(String fileId, String classpath, String source) {
        byte[] xml = readAllBytes(classpath);
        // sourcePath is null for non-LocalFS; set a Path when you simulate localfs archiving
        return new WorkItem(fileId, xml, null, source);
    }

    public static WorkItem fromResourceLocalFs(String fileId, String classpath, Path sourcePath) {
        byte[] xml = readAllBytes(classpath);
        return new WorkItem(fileId, xml, sourcePath, "localfs");
    }

    private static byte[] readAllBytes(String classpath) {
        try (InputStream in = TestWorkItems.class.getResourceAsStream(classpath)) {
            if (in == null) throw new IllegalArgumentException("Resource not found: " + classpath);
            return in.readAllBytes();
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
}
