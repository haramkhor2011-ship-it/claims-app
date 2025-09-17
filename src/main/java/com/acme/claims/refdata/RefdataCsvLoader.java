package com.acme.claims.refdata;

import com.acme.claims.refdata.config.RefdataBootstrapProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.function.Function;

@Slf4j
@Service
@RequiredArgsConstructor
public class RefdataCsvLoader {

    private final JdbcTemplate jdbc;
    private final ResourceLoader resources;
    private final RefdataBootstrapProperties props;

    // ===== Public file loaders (kept same method names for call sites) =====

    @Transactional
    public int loadPayers() {
        return loadCsv("payers.csv",
                Set.of("payer_code","name","status"),
                recs -> batchUpsert(recs, """
                        insert into claims_ref.payer(payer_code, name, status)
                        values (?,?,?)
                        on conflict (payer_code) do update set name=excluded.name, status=excluded.status
                        """,
                        (rec) -> new Object[]{
                                req(rec,"payer_code", 1, 120, true),
                                opt(rec,"name", 0, 256),
                                def(rec,"status","ACTIVE", 1, 32, true)
                        }));
    }

    @Transactional
    public int loadFacilities() {
        return loadCsv("facilities.csv",
                Set.of("facility_code","name","city","country","status"),
                recs -> batchUpsert(recs, """
                        insert into claims_ref.facility(facility_code, name, city, country, status)
                        values (?,?,?,?,?)
                        on conflict (facility_code) do update
                           set name=excluded.name, city=excluded.city, country=excluded.country, status=excluded.status
                        """,
                        (rec) -> new Object[]{
                                req(rec,"facility_code", 1, 120, true),
                                opt(rec,"name", 0, 256),
                                opt(rec,"city", 0, 128),
                                opt(rec,"country", 0, 64),
                                def(rec,"status","ACTIVE", 1, 32, true)
                        }));
    }

    @Transactional
    public int loadProviders() {
        return loadCsv("providers.csv",
                Set.of("provider_code","name","status"),
                recs -> batchUpsert(recs, """
                        insert into claims_ref.provider(provider_code, name, status)
                        values (?,?,?)
                        on conflict (provider_code) do update set name=excluded.name, status=excluded.status
                        """,
                        (rec) -> new Object[]{
                                req(rec,"provider_code", 1, 120, true),
                                opt(rec,"name", 0, 256),
                                def(rec,"status","ACTIVE", 1, 32, true)
                        }));
    }

    @Transactional
    public int loadClinicians() {
        return loadCsv("clinicians.csv",
                Set.of("clinician_code","name","specialty","status"),
                recs -> batchUpsert(recs, """
                        insert into claims_ref.clinician(clinician_code, name, specialty, status)
                        values (?,?,?,?)
                        on conflict (clinician_code) do update
                           set name=excluded.name, specialty=excluded.specialty, status=excluded.status
                        """,
                        (rec) -> new Object[]{
                                req(rec,"clinician_code", 1, 120, true),
                                opt(rec,"name", 0, 256),
                                opt(rec,"specialty", 0, 128),
                                def(rec,"status","ACTIVE", 1, 32, true)
                        }));
    }

    @Transactional
    public int loadActivityCodes() {
        return loadCsv("activity_codes.csv",
                Set.of("code","code_system","description","status"),
                recs -> batchUpsert(recs, """
                        insert into claims_ref.activity_code(code, code_system, description, status)
                        values (?,?,?,?)
                        on conflict (code, code_system) do update
                           set description=excluded.description, status=excluded.status
                        """,
                        (rec) -> new Object[]{
                                req(rec,"code", 1, 64, true),                               // ActivityCode: no whitespace
                                def(rec,"code_system","LOCAL", 1, 32, true),
                                opt(rec,"description", 0, 512),
                                def(rec,"status","ACTIVE", 1, 32, true)
                        }));
    }

    @Transactional
    public int loadDiagnosisCodes() {
        return loadCsv("diagnosis_codes.csv",
                Set.of("code","code_system","description","status"),
                recs -> batchUpsert(recs, """
                        insert into claims_ref.diagnosis_code(code, code_system, description, status)
                        values (?,?,?,?)
                        on conflict (code, code_system) do update
                           set description=excluded.description, status=excluded.status
                        """,
                        (rec) -> new Object[]{
                                req(rec,"code", 1, 16, true),                                // ICD-10 codes are short
                                def(rec,"code_system","ICD-10", 1, 32, true),
                                opt(rec,"description", 0, 512),
                                def(rec,"status","ACTIVE", 1, 32, true)
                        }));
    }

    @Transactional
    public int loadDenialCodes() {
        return loadCsv("denial_codes.csv",
                Set.of("code","description","payer_code"),
                recs -> batchUpsert(recs, """
                        insert into claims_ref.denial_code(code, description, payer_code)
                        values (?,?,?)
                        on conflict (code) do update set description=excluded.description, payer_code=excluded.payer_code
                        """,
                        (rec) -> new Object[]{
                                req(rec,"code", 1, 64, true),
                                opt(rec,"description", 0, 512),
                                opt(rec,"payer_code", 0, 120)
                        }));
    }

    @Transactional
    public int loadContractPackages() {
        return loadCsv("contract_packages.csv",
                Set.of("package_name","description","status"),
                recs -> batchUpsert(recs, """
                        insert into claims_ref.contract_package(package_name, description, status)
                        values (?,?,?)
                        on conflict (package_name) do update set description=excluded.description, status=excluded.status
                        """,
                        (rec) -> new Object[]{
                                req(rec,"package_name", 1, 120, false),                      // package names may have spaces
                                opt(rec,"description", 0, 512),
                                def(rec,"status","ACTIVE", 1, 32, true)
                        }));
    }

    // ===== Generic CSV framework (strict/lenient, headers, batching) =====

    private int loadCsv(String fileName,
                        Set<String> requiredHeaders,
                        Function<List<CSVRecord>, Integer> batchHandler) {
        final String uri = (props.getLocation().endsWith("/") ? props.getLocation() : props.getLocation()+"/") + fileName;
        final Resource res = resources.getResource(uri);

        if (!res.exists()) {
            final boolean required = props.isStrict() && props.getRequiredFiles().contains(fileName);
            final String msg = "Refdata CSV not found: " + uri + (required ? " [STRICT]" : " [optional]");
            if (required) throw new IllegalStateException(msg);
            log.info("{} — skipping.", msg);
            return 0;
        }

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(res.getInputStream(), StandardCharsets.UTF_8))) {
            CSVFormat format = CSVFormat.DEFAULT.builder()
                    .setHeader()
                    .setSkipHeaderRecord(true)
                    .setTrim(true)
                    .setIgnoreSurroundingSpaces(true)
                    .setDelimiter(props.getDelimiter())
                    .build();

            try (CSVParser parser = new CSVParser(reader, format)) {
                Map<String, Integer> headerMap = parser.getHeaderMap();
                validateHeaders(fileName, headerMap.keySet(), requiredHeaders);

                // Collect all records (we apply JDBC batch ourselves)
                List<CSVRecord> all = parser.getRecords();
                if (all.isEmpty()) {
                    log.info("Refdata CSV empty: {} — nothing to do.", fileName);
                    return 0;
                }
                return batchHandler.apply(all);
            }
        } catch (RuntimeException re) {
            // honor strictness
            if (props.isStrict()) throw re;
            log.error("Refdata load failed (lenient): {} -> {}", fileName, re.getMessage(), re);
            return 0;
        } catch (Exception e) {
            if (props.isStrict()) throw new IllegalStateException("Failed to load " + fileName + ": " + e.getMessage(), e);
            log.error("Refdata load failed (lenient): {} -> {}", fileName, e.getMessage(), e);
            return 0;
        }
    }

    private void validateHeaders(String fileName, Set<String> actual, Set<String> required) {
        Set<String> missing = new LinkedHashSet<>(required);
        missing.removeAll(lowercase(actual));
        if (!missing.isEmpty()) {
            String msg = "CSV " + fileName + " missing headers: " + missing;
            if (props.isStrict()) throw new IllegalStateException(msg);
            log.warn("{} (lenient mode: continuing, rows may be skipped)", msg);
        }
    }

    private Set<String> lowercase(Set<String> names) {
        Set<String> out = new HashSet<>();
        for (String n : names) out.add(n == null ? null : n.toLowerCase(Locale.ROOT));
        return out;
    }

    private int batchUpsert(List<CSVRecord> recs, String sql, Function<CSVRecord,Object[]> binder) {
        final int batch = Math.max(50, props.getBatchSize());
        int total = 0;

        List<Object[]> buffer = new ArrayList<>(batch);
        for (CSVRecord r : recs) {
            try {
                buffer.add(binder.apply(r));
                if (buffer.size() == batch) {
                    total += execBatch(sql, buffer);
                    buffer.clear();
                }
            } catch (IllegalArgumentException ex) {
                // validation error for this row
                handleRowError(r, ex);
            }
        }
        if (!buffer.isEmpty()) total += execBatch(sql, buffer);
        log.info("Refdata upsert ok: rows affected={}", total);
        return total;
    }

    private int execBatch(String sql, List<Object[]> buffer) {
        try {
            int[] counts = jdbc.batchUpdate(sql, buffer);
            int sum = 0; for (int c : counts) sum += Math.max(0, c);
            return sum;
        } catch (DataAccessException dae) {
            if (props.isStrict()) throw dae;
            log.error("Batch upsert failed (lenient): {}", dae.getMessage(), dae);
            return 0;
        }
    }

    private void handleRowError(CSVRecord r, IllegalArgumentException ex) {
        String preview = "[line " + r.getRecordNumber() + "] " + ex.getMessage();
        if (props.isStrict()) throw ex;
        log.warn("Refdata row skipped (lenient): {}", preview);
    }

    // ===== Field helpers (trim, defaults, XSD-like checks) ==================

    private static String trimOrNull(String v) {
        if (v == null) return null;
        String t = v.trim();
        return t.isEmpty() ? null : t;
    }

    /** Required field with optional "no whitespace" check and length bounds. */
    private static String req(CSVRecord rec, String name, int minLen, int maxLen, boolean noWhitespace) {
        String v = trimOrNull(rec.get(name));
        if (v == null) throw new IllegalArgumentException("Missing required column '" + name + "'");
        if (noWhitespace && containsWhitespace(v)) {
            throw new IllegalArgumentException("Column '" + name + "' contains whitespace");
        }
        if (v.length() < minLen || v.length() > maxLen) {
            throw new IllegalArgumentException("Column '" + name + "' length out of bounds");
        }
        return v;
    }

    /** Optional field with length bounds; returns null if blank. */
    private static String opt(CSVRecord rec, String name, int minLen, int maxLen) {
        if (!rec.isMapped(name)) return null;
        String v = trimOrNull(rec.get(name));
        if (v == null) return null;
        if (v.length() < minLen || v.length() > maxLen) {
            throw new IllegalArgumentException("Column '" + name + "' length out of bounds");
        }
        return v;
    }

    /** Defaulted field (if blank) with length bounds and optional "no whitespace". */
    private static String def(CSVRecord rec, String name, String def, int minLen, int maxLen, boolean noWhitespace) {
        String v = rec.isMapped(name) ? trimOrNull(rec.get(name)) : null;
        if (v == null) v = def;
        if (noWhitespace && containsWhitespace(v)) {
            throw new IllegalArgumentException("Column '" + name + "' contains whitespace");
        }
        if (v.length() < minLen || v.length() > maxLen) {
            throw new IllegalArgumentException("Column '" + name + "' length out of bounds");
        }
        return v;
    }

    private static boolean containsWhitespace(String s) {
        for (int i = 0; i < s.length(); i++) {
            if (Character.isWhitespace(s.charAt(i))) return true;
        }
        return false;
    }
}
