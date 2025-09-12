// src/main/java/com/acme/claims/soap/fetch/DhpoFetchCoordinator.java
package com.acme.claims.soap.fetch;

import com.acme.claims.domain.model.entity.FacilityDhpoConfig;
import com.acme.claims.domain.repo.FacilityDhpoConfigRepo;
import com.acme.claims.ingestion.fetch.soap.DhpoFetchInbox;
import com.acme.claims.security.ame.CredsCipherService;
import com.acme.claims.soap.SoapGateway;
import com.acme.claims.soap.SoapProperties;
import com.acme.claims.soap.config.DhpoClientProperties;
import com.acme.claims.soap.db.ToggleRepo;
import com.acme.claims.soap.parse.DownloadFileParser;
import com.acme.claims.soap.parse.ListFilesParser;
import com.acme.claims.soap.req.DownloadTransactionFileRequest;
import com.acme.claims.soap.req.GetNewTransactionsRequest;
import com.acme.claims.soap.req.SearchTransactionsRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

@Slf4j
@Component
@Profile("soap")
@RequiredArgsConstructor
public class DhpoFetchCoordinator {

    private final SoapGateway gateway;
    private final SoapProperties soapProps;
    private final FacilityDhpoConfigRepo facilities;
    private final ToggleRepo toggles;
    private final DhpoClientProperties dhpoProps;
    private final StagingService staging;
    private final CredsCipherService creds; // << use AME to decrypt per-facility
    private final DhpoFetchInbox inbox;
    private final DhpoFileRegistry fileRegistry;

    @Value("${claims.fetch.stageToDisk.force:false}") boolean forceDisk;
    @Value("${claims.fetch.stageToDisk.sizeThresholdBytes:26214400}") long sizeThreshold;
    @Value("${claims.fetch.stageToDisk.latencyThresholdMs:8000}") long latencyThreshold;
    @Value("${claims.fetch.stageToDisk.readyDir:data/ready}") String readyDir;

    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss");

    // ===== Delta poll (GetNewTransactions) =====
    @Scheduled(fixedDelayString = "${claims.soap.poll.fixedDelayMs:1800000}", initialDelay = 0) // default 30 min
    public void pollNew() {
        // disabled via db - only admin can toggle it
        if (!toggles.isEnabled("dhpo.client.getNewEnabled")) {
            return;
        }
        var list = facilities.findByActiveTrue();
        for (var f : list) {
            try {
                processDelta(f);
            } catch (Exception e) {
                log.error("Facility {} delta poll failed: {}", f.getFacilityCode(), e.toString());
            }
        }
    }

    private void processDelta(FacilityDhpoConfig f) {
        var plain = creds.decryptFor(f); // decrypt once per facility per call
        var req = GetNewTransactionsRequest.build(plain.login(), plain.pwd(), false /*soap1.1*/);
        var resp = gateway.call(req);

        var parsed = new ListFilesParser().parse(resp.envelopeXml());
        if (!handleResultCode("GetNewTransactions", parsed.code(), parsed.errorMessage(), f.getFacilityCode())) return;

        if (parsed.files().isEmpty()) {
            log.debug("Facility {}: no new transactions", f.getFacilityCode());
            return;
        }
        log.info("Facility {}: {} new items", f.getFacilityCode(), parsed.files().size());

        for (var row : parsed.files()) {
            // For GetNewTransactions DHPO typically returns isDownloaded=false; we download + stage all.
            downloadAndStage(f, row.fileId());
        }
    }

    // ===== Backfill/ops search (toggle) =====
    @Scheduled(fixedDelayString = "${claims.soap.poll.fixedDelayMs:1800000}", initialDelay = 5000)
    public void pollSearch() {
        var list = facilities.findByActiveTrue();
        for (var f : list) {
            try {
                // Two searches per facility: submissions(sent=2, direction=1) & remittances(received=8, direction=2)
                searchWindow(f, 1, 2);
                searchWindow(f, 2, 8);
            } catch (Exception e) {
                log.error("Facility {} search poll failed: {}", f.getFacilityCode(), e.toString());
            }
        }
    }

    private void searchWindow(FacilityDhpoConfig f, int direction, int transactionId) {
        var plain = creds.decryptFor(f);
        LocalDateTime to = LocalDateTime.now();
        LocalDateTime from = to.minusDays(100);

        var req = SearchTransactionsRequest.build(
                plain.login(), plain.pwd(), direction,
                f.getFacilityCode(), "",                            // callerLicense = facility_code, ePartner blank
                transactionId, 1,                                   // TransactionStatus=1 (new/undownloaded)
                FMT.format(from), FMT.format(to),
                0, 500, false /*soap1.1*/
        );
        var resp = gateway.call(req);
        var parsed = new ListFilesParser().parse(resp.envelopeXml());
        if (!handleResultCode("SearchTransactions", parsed.code(), parsed.errorMessage(), f.getFacilityCode())) return;

        long candidates = parsed.files().stream().filter(fr -> fr.isDownloaded()==null || Boolean.FALSE.equals(fr.isDownloaded())).count();
        log.info("Facility {} Search dir={} tx={} candidates={}",
                f.getFacilityCode(), direction, transactionId, candidates);

        parsed.files().stream()
                .filter(fr -> fr.isDownloaded()==null || Boolean.FALSE.equals(fr.isDownloaded()))
                .forEach(fr -> downloadAndStage(f, fr.fileId()));
    }

    // ===== Download + dynamic staging =====
    private void downloadAndStage(FacilityDhpoConfig f, String fileId) {
        var plain = creds.decryptFor(f);
        long t0 = System.nanoTime();
        var req = DownloadTransactionFileRequest.build(plain.login(), plain.pwd(), fileId, false /*soap1.1*/);
        var resp = gateway.call(req);
        long dlMs = (System.nanoTime() - t0) / 1_000_000;

        var parsed = new DownloadFileParser().parse(resp.envelopeXml());
        if (!handleResultCode("DownloadTransactionFile", parsed.code(), parsed.errorMessage(), f.getFacilityCode())) return;

        byte[] fileBytes = parsed.fileBytes();
        if (fileBytes.length == 0 || !new String(fileBytes, StandardCharsets.UTF_8).trim().startsWith("<")) {
            log.error("Facility {} fileId {}: downloaded bytes empty or not XML", f.getFacilityCode(), fileId);
            return;
        }

        var pol = new StagingPolicy(forceDisk, sizeThreshold, latencyThreshold, readyDir);
        try {
            var staged = staging.decideAndStage(fileBytes, parsed.fileName(), dlMs, pol);
            log.info("Facility {} fileId {} staged as {} (name={})", f.getFacilityCode(), fileId, staged.mode(), staged.fileId());
            // Hand-off to parser/persist remains in your existing flow.
            fileRegistry.remember(fileId, f.getFacilityCode());
            inbox.submitSoap(fileId, fileBytes);
            // NOTE: SetTransactionDownloaded will be invoked post-verify with **fieldId** (your rule).
        } catch (Exception e) {
            log.error("Facility {} fileId {} staging failed: {}", f.getFacilityCode(), fileId, e.toString());
        }
    }

    // ===== Common result handling (retry only on -4; transport retries live in SoapGateway) =====
    private boolean handleResultCode(String op, int code, String err, String facility) {
        if (code == Integer.MIN_VALUE) {
            log.error("Facility {} {}: missing result code", facility, op);
            return false;
        }
        if (code >= 0) { // success or no-data; >0 may be warnings
            if (code > 0 && err != null && !err.isBlank()) {
                log.info("{} facility {} returned warnings code={} msg={}", op, facility, code, err);
            }
            return true;
        }
        // error (<0): we only retry on transport or DHPO -4 at gateway level; coordinator logs and moves on
        log.warn("Facility {} {} error code={} msg={}", facility, op, code, err);
        return false;
    }
}
