// src/main/java/com/acme/claims/soap/fetch/DhpoFetchCoordinator.java
package com.acme.claims.soap.fetch;

import com.acme.claims.domain.model.entity.FacilityDhpoConfig;
import com.acme.claims.domain.repo.FacilityDhpoConfigRepo;
import com.acme.claims.ingestion.fetch.soap.DhpoFetchInbox;
import com.acme.claims.metrics.DhpoMetrics;
import com.acme.claims.security.ame.CredsCipherService;
import com.acme.claims.soap.SoapProperties;
import com.acme.claims.soap.config.DhpoClientProperties;
import com.acme.claims.soap.db.ToggleRepo;
import com.acme.claims.soap.fetch.exception.DhpoCredentialException;
import com.acme.claims.soap.fetch.exception.DhpoFetchException;
import com.acme.claims.soap.fetch.exception.DhpoSoapException;
import com.acme.claims.soap.fetch.exception.DhpoStagingException;
import com.acme.claims.soap.parse.DownloadFileParser;
import com.acme.claims.soap.parse.ListFilesParser;
import com.acme.claims.soap.req.DownloadTransactionFileRequest;
import com.acme.claims.soap.req.GetNewTransactionsRequest;
import com.acme.claims.soap.req.SearchTransactionsRequest;
import com.acme.claims.soap.transport.SoapCaller;
import com.acme.claims.soap.util.XmlPayloads;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.dao.DataAccessException;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Future;
import java.util.concurrent.Semaphore;
import java.util.concurrent.StructuredTaskScope;

/**
 * Coordinates DHPO SOAP fetching across facilities.
 *
 * Runtime behavior (when profile "soap" is active):
 * - Two schedulers drive periodic work:
 *   - pollNew(): delta polling via GetNewTransactions (default every 30m; toggle: dhpo.new.enabled)
 *   - pollSearch(): backfill/ops search via SearchTransactions for submissions and remittances
 *     (default every 30m; toggle: dhpo.search.enabled)
 *
 * Concurrency model:
 * - A reentrancy guard per scheduler (AtomicBoolean deltaRunning/searchRunning) prevents overlaps between runs.
 * - Facilities are processed in parallel using StructuredTaskScope with virtual threads.
 * - Within each facility, downloads are bounded by a Semaphore sized from SoapProperties.downloadConcurrency.
 * - Each file download is executed in a virtual thread and staged either to disk or kept in memory depending on
 *   StagingPolicy (force flag, size threshold, latency threshold); then handed off to the ingestion inbox.
 *
 * Idempotency / safety:
 * - A short-lived in-memory inflight registry (ConcurrentMap with TTL) prevents duplicate processing of the same
 *   facility|fileId during concurrent polls.
 * - Result codes from DHPO are validated and transport errors do not crash the scheduler loops.
 * - Facility credentials are decrypted once per facility per batch and passed down to download calls.
 *
 * Observability:
 * - DhpoMetrics records per-download metrics (mode, size, latency); logs summarize candidates and outcomes.
 *
 * Configuration knobs (via properties):
 * - claims.soap.poll.fixedDelayMs: poll cadence for both schedulers
 * - claims.fetch.stageToDisk.[force|sizeThresholdBytes|latencyThresholdMs|readyDir]: staging policy
 * - claims.soap.downloadConcurrency: per-facility concurrent downloads
 * - dhpo.searchDaysBack: lookback window for SearchTransactions
 */
@Slf4j
@Component
@Profile("soap")
@RequiredArgsConstructor
public class DhpoFetchCoordinator {

    //private final SoapGateway gateway;
    private final SoapCaller soapCaller;
    private final SoapProperties soapProps;
    private final FacilityDhpoConfigRepo facilities;
    private final ToggleRepo toggles;
    private final DhpoClientProperties dhpoProps;
    private final StagingService staging;
    private final CredsCipherService creds; // << use AME to decrypt per-facility
    private final DhpoFetchInbox inbox;
    private final DhpoFileRegistry fileRegistry;
    private final DhpoMetrics dhpoMetrics;
    private final java.util.concurrent.atomic.AtomicBoolean searchRunning = new java.util.concurrent.atomic.AtomicBoolean(false);
    private final java.util.concurrent.atomic.AtomicBoolean deltaRunning  = new java.util.concurrent.atomic.AtomicBoolean(false);



    @Value("${claims.fetch.stageToDisk.force:false}") boolean forceDisk;
    @Value("${claims.fetch.stageToDisk.sizeThresholdBytes:26214400}") long sizeThreshold;
    @Value("${claims.fetch.stageToDisk.latencyThresholdMs:8000}") long latencyThreshold;
    @Value("${claims.fetch.stageToDisk.readyDir:data/ready}") String readyDir;

    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss");

    // ===== Delta poll (GetNewTransactions) =====
    @Scheduled(fixedDelayString = "${claims.soap.poll.fixedDelayMs:1800000}", initialDelay = 0) // default 30 min
    public void pollNew() {
        // disabled via db - only admin can toggle it
        if (!toggles.isEnabled("dhpo.new.enabled")) {
            return;
        }
        if (!deltaRunning.compareAndSet(false, true)) {
            log.debug("pollNew already running; skip");
            return;
        }
        try {
            List<FacilityDhpoConfig> list;
            try {
                list = facilities.findByActiveTrue();
            } catch (DataAccessException e) {
                log.error("Failed to fetch active facilities for delta poll: {}", e.getMessage(), e);
                return;
            }
            
            if (list.isEmpty()) {
                log.debug("No active facilities found for delta poll");
                return;
            }
            
            try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
                for (var f : list) {
                    scope.fork(() -> {
                        try {
                            processDelta(f);
                            return null;
                        } catch (DhpoFetchException e) {
                            // Log structured exception with context
                            log.error("Facility {} delta poll failed [{}]: {}", 
                                    e.getFacilityCode(), e.getErrorCode(), e.getMessage(), e);
                            throw e;
                        } catch (Exception e) {
                            // Wrap unexpected exceptions
                            log.error("Facility {} delta poll failed with unexpected error: {}", 
                                    f.getFacilityCode(), e.getMessage(), e);
                            throw new DhpoFetchException(f.getFacilityCode(), "DELTA_POLL", 
                                    "UNEXPECTED_ERROR", "Unexpected error during delta poll", e);
                        }
                    });
                }
                scope.join();
                scope.throwIfFailed();
            }
        } catch (Exception e) {
            log.error("Delta poll scheduler failed: {}", e.getMessage(), e);
        } finally {
            deltaRunning.set(false);
        }
    }

    private void processDelta(FacilityDhpoConfig f) {
        List<Future<?>> futures;
        final int downloadConcurrency = Math.max(1, soapProps.downloadConcurrency());
        final Semaphore downloadSlots = new Semaphore(downloadConcurrency);
        
        // Decrypt credentials with proper error handling
        CredsCipherService.PlainCreds plain;
        try {
            plain = creds.decryptFor(f);
        } catch (Exception e) {
            throw new DhpoCredentialException(f.getFacilityCode(), 
                    "Failed to decrypt credentials for facility", e);
        }
        
        // Build and execute SOAP request with error handling
        var req = GetNewTransactionsRequest.build(plain.login(), plain.pwd(), false /*soap1.1*/);
        com.acme.claims.soap.SoapGateway.SoapResponse resp;
        try {
            resp = soapCaller.call(req);
        } catch (Exception e) {
            throw new DhpoSoapException(f.getFacilityCode(), "GetNewTransactions", 
                    Integer.MIN_VALUE, "SOAP call failed", e);
        }

        // Parse response with error handling
        ListFilesParser.Result parsed;
        try {
            parsed = listFilesParser.parse(resp.envelopeXml());
        } catch (Exception e) {
            throw new DhpoFetchException(f.getFacilityCode(), "PARSE_RESPONSE", 
                    "PARSE_ERROR", "Failed to parse GetNewTransactions response", e);
        }
        
        if (!handleResultCode("GetNewTransactions", parsed.code(), parsed.errorMessage(), f.getFacilityCode())) {
            return;
        }

        if (parsed.files().isEmpty()) {
            log.debug("Facility {}: no new transactions", f.getFacilityCode());
            return;
        }
        
        log.info("Facility {}: {} new items", f.getFacilityCode(), parsed.files().size());
        futures = new ArrayList<>(parsed.files().size());
        
        try (var vt = java.util.concurrent.Executors.newVirtualThreadPerTaskExecutor()) {
            for (var row : parsed.files()) {
                futures.add(vt.submit(() -> {
                    if (!tryMarkInflight(f.getFacilityCode(), row.fileId())) {
                        log.debug("Skip duplicate inflight {}|{}", f.getFacilityCode(), row.fileId());
                        return;
                    }
                    
                    try {
                        downloadSlots.acquireUninterruptibly();
                        downloadAndStage(f, row.fileId(), plain);
                    } catch (Exception e) {
                        log.error("Failed to download and stage file {} for facility {}: {}", 
                                row.fileId(), f.getFacilityCode(), e.getMessage(), e);
                    } finally {
                        downloadSlots.release();
                        unmarkInflight(f.getFacilityCode(), row.fileId());
                    }
                }));
            }
        } catch (Exception e) {
            throw new DhpoFetchException(f.getFacilityCode(), "VIRTUAL_THREAD_EXECUTION", 
                    "THREAD_ERROR", "Failed to execute virtual threads for downloads", e);
        }
    }

    // ===== Backfill/ops search (toggle) =====
    @Scheduled(fixedDelayString = "${claims.soap.poll.fixedDelayMs:1800000}", initialDelay = 5000)
    public void pollSearch() {
        if (!toggles.isEnabled("dhpo.search.enabled")) {
            return;
        }
        if (!searchRunning.compareAndSet(false, true)) {
            log.debug("pollSearch already running; skip");
            return;
        }
        try {
            List<FacilityDhpoConfig> list;
            try {
                list = facilities.findByActiveTrue();
            } catch (DataAccessException e) {
                log.error("Failed to fetch active facilities for search poll: {}", e.getMessage(), e);
                return;
            }
            
            log.info("Active facility : {}", list.size());
            
            if (list.isEmpty()) {
                log.debug("No active facilities found for search poll");
                return;
            }
            
            try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
                for (var f : list) {
                    scope.fork(() -> {
                        try {
                            // Two searches per facility: submissions(sent=2, direction=1) & remittances(received=8, direction=2)
                            searchWindow(f, 1, 2);
                            searchWindow(f, 2, 8);
                            return null;
                        } catch (DhpoFetchException e) {
                            // Log structured exception with context
                            log.error("Facility {} search poll failed [{}]: {}", 
                                    e.getFacilityCode(), e.getErrorCode(), e.getMessage(), e);
                            throw e;
                        } catch (Exception e) {
                            // Wrap unexpected exceptions
                            log.error("Facility {} search poll failed with unexpected error: {}", 
                                    f.getFacilityCode(), e.getMessage(), e);
                            throw new DhpoFetchException(f.getFacilityCode(), "SEARCH_POLL", 
                                    "UNEXPECTED_ERROR", "Unexpected error during search poll", e);
                        }
                    });
                }
                scope.join();
                scope.throwIfFailed();
            }
        } catch (Exception e) {
            log.error("Search poll scheduler failed: {}", e.getMessage(), e);
        } finally {
            searchRunning.set(false);
        }
    }

    private void searchWindow(FacilityDhpoConfig f, int direction, int transactionId) {
        final int downloadConcurrency = Math.max(1, soapProps.downloadConcurrency());
        final Semaphore downloadSlots = new Semaphore(downloadConcurrency);
        List<Future<?>> futures = new ArrayList<>();
        
        // Decrypt credentials with proper error handling
        CredsCipherService.PlainCreds plain;
        try {
            plain = creds.decryptFor(f);
        } catch (Exception e) {
            throw new DhpoCredentialException(f.getFacilityCode(), 
                    "Failed to decrypt credentials for facility", e);
        }
        
        LocalDateTime to = LocalDateTime.now();
        int daysBack = Math.max(1, dhpoProps.searchDaysBack());
        LocalDateTime from = to.minusDays(daysBack);

        var req = SearchTransactionsRequest.build(
                plain.login(), plain.pwd(), direction,
                f.getFacilityCode(), "",                            // callerLicense = facility_code, ePartner blank
                transactionId, 1,                                   // TransactionStatus=1 (new/undownloaded)
                FMT.format(from), FMT.format(to),
                1, 500, false /*soap1.1*/
        );
        
        // Execute SOAP call - retry logic is handled in HttpSoapCaller
        com.acme.claims.soap.SoapGateway.SoapResponse resp;
        try {
            resp = soapCaller.call(req);
        } catch (Exception e) {
            throw new DhpoSoapException(f.getFacilityCode(), "SearchTransactions", 
                    Integer.MIN_VALUE, "SOAP call failed", e);
        }
        
        // Parse response with error handling
        ListFilesParser.Result parsed;
        try {
            parsed = listFilesParser.parse(resp.envelopeXml());
        } catch (Exception e) {
            throw new DhpoFetchException(f.getFacilityCode(), "PARSE_RESPONSE", 
                    "PARSE_ERROR", "Failed to parse SearchTransactions response", e);
        }
        
        if (!handleResultCode("SearchTransactions", parsed.code(), parsed.errorMessage(), f.getFacilityCode())) {
            return;
        }

        long candidates = parsed.files().stream().filter(fr -> fr.isDownloaded()==null || Boolean.FALSE.equals(fr.isDownloaded())).count();
        log.info("Facility {} Search dir={} tx={} candidates={}",
                f.getFacilityCode(), direction, transactionId, candidates);
        
        try (var vt = java.util.concurrent.Executors.newVirtualThreadPerTaskExecutor()) {
            for(var file : parsed.files().stream().filter(fr -> fr.isDownloaded() == null || !fr.isDownloaded()).toList()) {
                futures.add(vt.submit(() -> {
                    if (!tryMarkInflight(f.getFacilityCode(), file.fileId())) {
                        log.debug("Skip duplicate inflight {}|{}", f.getFacilityCode(), file.fileId());
                        return;
                    }
                    
                    try {
                        downloadSlots.acquireUninterruptibly();
                        downloadAndStage(f, file.fileId(), plain);
                    } catch (Exception e) {
                        log.error("Failed to download and stage file {} for facility {}: {}", 
                                file.fileId(), f.getFacilityCode(), e.getMessage(), e);
                    } finally {
                        downloadSlots.release();
                        unmarkInflight(f.getFacilityCode(), file.fileId());
                    }
                }));
            }
        } catch (Exception e) {
            throw new DhpoFetchException(f.getFacilityCode(), "VIRTUAL_THREAD_EXECUTION", 
                    "THREAD_ERROR", "Failed to execute virtual threads for search downloads", e);
        }
    }

    // ===== Download + dynamic staging =====
    /**
     * Downloads a DHPO file for the given facility and stages it based on policy.
     * - Uses normalized UTF-8 XML bytes; rejects malformed payloads
     * - Records metrics and submits either path-based (DISK) or bytes-based (MEM) to the inbox
     */
    private void downloadAndStage(FacilityDhpoConfig f, String fileId, CredsCipherService.PlainCreds plain) {
        long t0 = System.nanoTime();
        var req = DownloadTransactionFileRequest.build(plain.login(), plain.pwd(), fileId, false /*soap1.1*/);
        
        // Execute SOAP call - retry logic is handled in HttpSoapCaller
        com.acme.claims.soap.SoapGateway.SoapResponse resp;
        try {
            resp = soapCaller.call(req);
        } catch (Exception e) {
            throw new DhpoSoapException(f.getFacilityCode(), "DownloadTransactionFile", 
                    Integer.MIN_VALUE, "SOAP call failed for fileId: " + fileId, e);
        }
        
        long dlMs = (System.nanoTime() - t0) / 1_000_000;

        // Parse response with error handling
        DownloadFileParser.Result parsed;
        try {
            parsed = downloadFileParser.parse(resp.envelopeXml());
        } catch (Exception e) {
            throw new DhpoFetchException(f.getFacilityCode(), "PARSE_DOWNLOAD_RESPONSE", 
                    "PARSE_ERROR", "Failed to parse DownloadTransactionFile response for fileId: " + fileId, e);
        }
        
        if (!handleResultCode("DownloadTransactionFile", parsed.code(), parsed.errorMessage(), f.getFacilityCode())) {
            return;
        }

        byte[] raw = parsed.fileBytes();
        if (raw == null || raw.length == 0) {
            log.warn("Facility {} fileId {}: downloaded file is empty", f.getFacilityCode(), fileId);
            return;
        }
        
        byte[] xmlBytes;
        try {
            xmlBytes = XmlPayloads.normalizeToUtf8OrThrow(raw);
            if (log.isDebugEnabled()) {
                log.debug("DHPO fileId={} xmlHeadHex={} xmlHeadText[48]={}",
                        fileId, XmlPayloads.headHex(xmlBytes, 48), XmlPayloads.headUtf8(xmlBytes, 48));
            }
        } catch (IllegalArgumentException bad) {
            // Keep ERROR here so it's visible, with bounded diagnostics
            log.error("Facility {} fileId {}: downloaded payload rejected: {}; headHex={} headText[48]={}",
                    f.getFacilityCode(), fileId, bad.getMessage(),
                    XmlPayloads.headHex(raw, 48), XmlPayloads.headUtf8(raw, 48));
            throw new DhpoFetchException(f.getFacilityCode(), "INVALID_PAYLOAD", 
                    "PAYLOAD_ERROR", "Downloaded payload is not valid XML for fileId: " + fileId, bad);
        }
//        var headHex = java.util.HexFormat.of().formatHex(java.util.Arrays.copyOf(fileBytes, Math.min(fileBytes.length, 64)));
//        String headText = new String(fileBytes, java.nio.charset.StandardCharsets.UTF_8)
//                .replaceAll("\\p{C}", " ")                 // strip control chars
//                .replace('\uFEFF',' ').trim();             // strip BOM if present
//        log.error("DHPO fileId={} headHex={} headText[32]={}", fileId, headHex,
//                headText.substring(0, Math.min(headText.length(), 32)));
//        boolean looksLikeXml = looksLikeXml(fileBytes);
//        boolean looksLikeZip = looksLikeZip(fileBytes);
//        log.error("looksLikeXml: {}, looksLikeZip: {}", looksLikeXml, looksLikeZip);
//        if (!looksLikeXml && !looksLikeZip) {
//            log.error("Facility {} fileId {}: downloaded bytes empty or not XML; headHex={} headText[32]={}",
//                    f.getFacilityCode(), fileId, headHex, headText.substring(0, Math.min(headText.length(), 32)));
//            //return;
//        }
//        log.error("fileId={} headHex={} headTextUtf8={}", fileId, headHex(fileBytes, 32), headTextUtf8(fileBytes, 128));
//        if (fileBytes.length == 0 || !new String(fileBytes, StandardCharsets.UTF_8).trim().startsWith("<")) {
//            log.error("Facility {} fileId {}: downloaded bytes empty or not XML", f.getFacilityCode(), fileId);
//            return;
//        }

        var pol = new StagingPolicy(forceDisk, sizeThreshold, latencyThreshold, readyDir);
        try {
            var staged = staging.decideAndStage(xmlBytes, parsed.fileName(), dlMs, pol);
            dhpoMetrics.recordDownload(f.getFacilityCode(), staged.mode().name().toLowerCase(),
                    xmlBytes.length, dlMs);

            log.info("Facility {} fileId {} staged as {} (name={})", f.getFacilityCode(), fileId, staged.mode(), staged.fileId());
            
            // Hand-off to parser/persist remains in your existing flow.
            try {
                fileRegistry.remember(fileId, f.getFacilityCode());
            } catch (Exception e) {
                log.warn("Failed to remember file {} for facility {}: {}", fileId, f.getFacilityCode(), e.getMessage());
            }
            
            try {
                switch (staged.mode()) {
                    case DISK -> inbox.submit(fileId, null, staged.path(), "soap"); // path-based
                    case MEM  -> inbox.submitSoap(fileId, staged.bytes());          // in-memory
                }
            } catch (Exception e) {
                throw new DhpoStagingException(f.getFacilityCode(), fileId, staged.mode().name(), 
                        "Failed to submit staged file to inbox", e);
            }
            // NOTE: SetTransactionDownloaded will be invoked once ingestion completes in pipeline class
        } catch (DhpoStagingException e) {
            // Re-throw staging exceptions as-is
            throw e;
        } catch (Exception e) {
            throw new DhpoStagingException(f.getFacilityCode(), fileId, "UNKNOWN", 
                    "Staging operation failed", e);
        }
    }

    // ===== Common result handling (transport retries are handled in HttpSoapCaller) =====
    private boolean handleResultCode(String op, int code, String err, String facility) {
        if (code == Integer.MIN_VALUE) {
            log.error("Facility {} {}: missing result code", facility, op);
            throw new DhpoSoapException(facility, op, code, "Missing result code in SOAP response");
        }
        if (code >= 0) { // success or no-data; >0 may be warnings
            if (code > 0 && err != null && !err.isBlank()) {
                log.info("{} facility {} returned warnings code={} msg={}", op, facility, code, err);
            }
            return true;
        }
        // error (<0): transport retries are handled in HttpSoapCaller; coordinator logs and throws
        log.warn("Facility {} {} error code={} msg={}", facility, op, code, err);
        
        // DHPO -4 is transient but transport layer should have already retried
        // If we get here, it means all retries were exhausted
        throw new DhpoSoapException(facility, op, code, "SOAP operation failed: " + err);
    }
//    private static String headHex(byte[] b, int n){
//        if (b == null) return "<null>";
//        int k = Math.min(n, b.length);
//        StringBuilder sb = new StringBuilder(k*2);
//        for (int i=0;i<k;i++) sb.append(String.format("%02X", b[i]));
//        return sb.toString();
//    }
//    private static String headTextUtf8(byte[] b, int n){
//        try {
//            if (b == null) return "<null>";
//            return new String(b, 0, Math.min(n, b.length), java.nio.charset.StandardCharsets.UTF_8)
//                    .replaceAll("\\s+"," ").trim();
//        } catch (Exception e) {
//            return "<decode-error:"+e.getClass().getSimpleName()+">";
//        }
//    }
//
//    // --- helpers (place as private static in the class) ---
//    private static boolean looksLikeXml(byte[] b) {
//        if (b == null || b.length == 0) return false;
//        int i = 0;
//        // skip UTF-8 BOM
//        if (b.length >= 3 && (b[0]&0xFF)==0xEF && (b[1]&0xFF)==0xBB && (b[2]&0xFF)==0xBF) i = 3;
//        // skip ASCII whitespace
//        while (i < b.length && (b[i]==0x20 || b[i]==0x09 || b[i]==0x0A || b[i]==0x0D)) i++;
//        return i < b.length && b[i] == '<';
//    }
//    private static boolean looksLikeZip(byte[] b) {
//        return b != null && b.length >= 2
//                && ((b[0] == 'P' && b[1] == 'K')      // ZIP
//                || ((b[0]&0xFF)==0x1F && (b[1]&0xFF)==0x8B)); // GZIP
//    }

    // Fields in DhpoFetchCoordinator
    private final java.util.concurrent.ConcurrentMap<String, Long> inflight = new java.util.concurrent.ConcurrentHashMap<>();
    private static final long INFLIGHT_TTL_MS = 10 * 60_000; // 10 minutes; tune as needed

    // Parser singletons to avoid per-call allocations
    private final transient ListFilesParser listFilesParser = new ListFilesParser();
    private final transient DownloadFileParser downloadFileParser = new DownloadFileParser();

    private boolean tryMarkInflight(String facility, String fileId) {
        try {
            final String key = facility + "|" + fileId;
            final long now = System.currentTimeMillis();
            // quick TTL cleanup
            inflight.entrySet().removeIf(e -> e.getValue() < now);
            // mark if absent
            return inflight.putIfAbsent(key, now + INFLIGHT_TTL_MS) == null;
        } catch (Exception e) {
            log.warn("Failed to mark inflight for facility {} fileId {}: {}", facility, fileId, e.getMessage());
            return false; // Conservative approach - don't process if we can't track
        }
    }
    
    private void unmarkInflight(String facility, String fileId) {
        try {
            inflight.remove(facility + "|" + fileId);
        } catch (Exception e) {
            log.warn("Failed to unmark inflight for facility {} fileId {}: {}", facility, fileId, e.getMessage());
        }
    }


}
