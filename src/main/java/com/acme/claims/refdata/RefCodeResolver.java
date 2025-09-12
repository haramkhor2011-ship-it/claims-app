package com.acme.claims.refdata;

import com.acme.claims.refdata.config.RefDataProperties;
import com.acme.claims.refdata.config.RefdataBootstrapProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class RefCodeResolver {

    private final JdbcTemplate jdbc;
    private final RefdataBootstrapProperties refdataBootstrapProperties;
    private final RefDataProperties refDataProperties;

    /* ========= Public API: return DB surrogate ids (or text PK note) ========= */

    /** Return payer.id for PayerID (e.g., INS025); creates row if missing. */
    @Transactional
    public Optional<Long> resolvePayer(String payerCode, String name, String actor, Long ingestionFileId, String claimExternalId) {
        return resolveId(
                "select id from claims_ref.payer where payer_code=?",
                ps -> ps.setString(1, payerCode),
                () -> jdbc.queryForObject("""
                        insert into claims_ref.payer(payer_code, name, status)
                        values (?,?, 'ACTIVE')
                        on conflict (payer_code) do update set name=coalesce(excluded.name, claims_ref.payer.name)
                        returning id
                        """, Long.class, payerCode, name),
                "claims_ref.payer", payerCode, null, actor, ingestionFileId, claimExternalId
        );
    }

    /** Return provider.id for ProviderID (often same format as facility). */
    @Transactional
    public Optional<Long> resolveProvider(String providerCode, String name, String actor, Long ingestionFileId, String claimExternalId) {
        return resolveId(
                "select id from claims_ref.provider where provider_code=?",
                ps -> ps.setString(1, providerCode),
                () -> jdbc.queryForObject("""
                        insert into claims_ref.provider(provider_code, name, status)
                        values (?,?, 'ACTIVE')
                        on conflict (provider_code) do update set name=coalesce(excluded.name, claims_ref.provider.name)
                        returning id
                        """, Long.class, providerCode, name),
                "claims_ref.provider", providerCode, null, actor, ingestionFileId, claimExternalId
        );
    }

    /** Return facility.id for Encounter.FacilityID (e.g., DHA-F-0045446). */
    @Transactional
    public Optional<Long> resolveFacility(String facilityCode, String name, String city, String country,
                                          String actor, Long ingestionFileId, String claimExternalId) {
        return resolveId(
                "select id from claims_ref.facility where facility_code=?",
                ps -> ps.setString(1, facilityCode),
                () -> jdbc.queryForObject("""
                        insert into claims_ref.facility(facility_code, name, city, country, status)
                        values (?,?,?,?,'ACTIVE')
                        on conflict (facility_code) do update
                          set name = coalesce(excluded.name, claims_ref.facility.name),
                              city = coalesce(excluded.city, claims_ref.facility.city),
                              country = coalesce(excluded.country, claims_ref.facility.country)
                        returning id
                        """, Long.class, facilityCode, name, city, country),
                "claims_ref.facility", facilityCode, null, actor, ingestionFileId, claimExternalId
        );
    }

    /** Return clinician.id for Activity.Clinician (e.g., DHA-P-0228312). */
    @Transactional
    public Optional<Long> resolveClinician(String clinicianCode, String name, String specialty,
                                           String actor, Long ingestionFileId, String claimExternalId) {
        return resolveId(
                "select id from claims_ref.clinician where clinician_code=?",
                ps -> ps.setString(1, clinicianCode),
                () -> jdbc.queryForObject("""
                        insert into claims_ref.clinician(clinician_code, name, specialty, status)
                        values (?,?,?, 'ACTIVE')
                        on conflict (clinician_code) do update
                          set name = coalesce(excluded.name, claims_ref.clinician.name),
                              specialty = coalesce(excluded.specialty, claims_ref.clinician.specialty)
                        returning id
                        """, Long.class, clinicianCode, name, specialty),
                "claims_ref.clinician", clinicianCode, null, actor, ingestionFileId, claimExternalId
        );
    }

    /** Return activity_code.id for (code, system) (e.g., 83036, CPT). */
    @Transactional
    public Optional<Long> resolveActivityCode(String code, String system, String description,
                                              String actor, Long ingestionFileId, String claimExternalId) {
        String sys = Optional.ofNullable(system).filter(s -> !s.isBlank()).orElse("LOCAL");
        return resolveId(
                "select id from claims_ref.activity_code where code=? and code_system=?",
                ps -> { ps.setString(1, code); ps.setString(2, sys); },
                () -> jdbc.queryForObject("""
                        insert into claims_ref.activity_code(code, code_system, description, status)
                        values (?,?,?, 'ACTIVE')
                        on conflict (code, code_system) do update
                          set description = coalesce(excluded.description, claims_ref.activity_code.description)
                        returning id
                        """, Long.class, code, sys, description),
                "claims_ref.activity_code", code, sys, actor, ingestionFileId, claimExternalId
        );
    }

    /** Return diagnosis_code.id for (code, system) (default ICD-10). */
    @Transactional
    public Optional<Long> resolveDiagnosisCode(String code, String system, String description,
                                               String actor, Long ingestionFileId, String claimExternalId) {
        String sys = Optional.ofNullable(system).filter(s -> !s.isBlank()).orElse("ICD-10");
        return resolveId(
                "select id from claims_ref.diagnosis_code where code=? and code_system=?",
                ps -> { ps.setString(1, code); ps.setString(2, sys); },
                () -> jdbc.queryForObject("""
                        insert into claims_ref.diagnosis_code(code, code_system, description, status)
                        values (?,?,?, 'ACTIVE')
                        on conflict (code, code_system) do update
                          set description = coalesce(excluded.description, claims_ref.diagnosis_code.description)
                        returning id
                        """, Long.class, code, sys, description),
                "claims_ref.diagnosis_code", code, sys, actor, ingestionFileId, claimExternalId
        );
    }

    /**
     * Return denial_code.id for denial codes.
     * NOTE: If your current table uses TEXT PK on code (no surrogate id), either:
     *  (a) add a bigserial id + unique(code) (recommended), or
     *  (b) change return type to Optional<String> and wire FK as TEXT.
     */
    @Transactional
    public Optional<Long> resolveDenialCode(String code, String description, String payerCode,
                                            String actor, Long ingestionFileId, String claimExternalId) {
        // Preferred schema: claims_ref.denial_code(id bigserial PK, code unique)
        // Adjust if you kept TEXT PK on code.
        //ensureDenialIdColumnExists(); // no-op if already there; see comment below.
        return resolveId(
                "select id from claims_ref.denial_code where code=?",
                ps -> ps.setString(1, code),
                () -> jdbc.queryForObject("""
                        insert into claims_ref.denial_code(code, description, payer_code)
                        values (?,?,?)
                        on conflict (code) do update
                          set description = coalesce(excluded.description, claims_ref.denial_code.description),
                              payer_code  = coalesce(excluded.payer_code, claims_ref.denial_code.payer_code)
                        returning id
                        """, Long.class, code, description, payerCode),
                "claims_ref.denial_code", code, null, actor, ingestionFileId, claimExternalId
        );
    }

    /** Return contract_package.package_name (text PK) as confirmation that it exists; we don’t use numeric id. */
    @Transactional
    public boolean ensureContractPackage(String packageName, String description,
                                         String actor, Long ingestionFileId, String claimExternalId) {
        Integer present = jdbc.query(
                "select 1 from claims_ref.contract_package where package_name=?",
                ps -> ps.setString(1, packageName),
                rs -> rs.next() ? 1 : null
        );
        if (present != null) return true;

        int inserted = jdbc.update("""
                insert into claims_ref.contract_package(package_name, description, status)
                values (?,?, 'ACTIVE')
                on conflict (package_name) do update
                  set description = coalesce(excluded.description, claims_ref.contract_package.description)
                """, packageName, description);
        if (inserted > 0) audit("claims_ref.contract_package", packageName, null, actor, ingestionFileId, claimExternalId, Map.of());
        return true;
    }

    /* =========================== Internals ================================ */

    private Optional<Long> resolveId(String findSql,
                                     SqlSetter findSetter,
                                     SupplierWithSql<Long> insertReturningId,
                                     String sourceTable,
                                     String code,
                                     String codeSystem,
                                     String actor,
                                     Long ingestionFileId,
                                     String claimExternalId) {
        // NOTE: You previously used refdataBootstrapProperties.isEnabled() to short-circuit the resolver.
        // Keeping that behavior unchanged: if bootstrap is disabled, we don’t resolve/insert and just return empty.
        if (!refdataBootstrapProperties.isEnabled()) {
            // PATCH: Resolver disabled by bootstrap flag → do nothing (caller persists only string columns)
            return Optional.empty();
        }

        // 1) Try to find existing id
        Long id = jdbc.query(findSql, findSetter::set, rs -> rs.next() ? rs.getLong(1) : null);
        if (id != null) {
            return Optional.of(id); // found → fast path
        }

        // 2) MISS → always audit the discovery (first time we see a new code)
        //    This is written regardless of auto-insert mode.
        // PATCH: audit-on-miss (before any optional insert)
        audit(sourceTable, code, codeSystem, actor, ingestionFileId, claimExternalId, Map.of());

        // 3) Respect the auto-insert flag:
        //    - true  → insert (UPSERT) and return new id
        //    - false → audit-only, return empty so caller writes *_ref_id = NULL (string columns still persisted)
        if (!refDataProperties.isAutoInsert()) {
            // PATCH: audit-only mode → do not mutate ref tables
            return Optional.empty();
        }

        // 4) Auto-insert mode: perform single round-trip UPSERT … RETURNING id (idempotent)
        // PATCH: perform insert and return id
        Long newId = insertReturningId.get();
        return Optional.ofNullable(newId);
    }


    private void audit(String sourceTable, String code, String codeSystem, String actor,
                       Long ingestionFileId, String claimExternalId, Map<String, Object> details) {
        jdbc.update("""
            insert into claims.code_discovery_audit(
              source_table, code, code_system, discovered_by, ingestion_file_id, claim_external_id, details
            ) values (?,?,?,?,?,?, to_jsonb(?::text))
            """, sourceTable, code, codeSystem, Optional.ofNullable(actor).orElse("SYSTEM"),
                ingestionFileId, claimExternalId, details == null ? "{}" : details.toString());
    }

    /* Small functional helpers (keep code readable) */
    @FunctionalInterface private interface SupplierWithSql<T> { T get(); }
    @FunctionalInterface private interface SqlSetter { void set(java.sql.PreparedStatement ps) throws java.sql.SQLException; }

    /* NOTE:
       If your current denial_code table lacks a surrogate id, add it once with:
         alter table claims_ref.denial_code add column if not exists id bigserial;
         create unique index if not exists uq_denial_code on claims_ref.denial_code(code);
       And prefer FK → denial_code(id). If you must keep TEXT PK, change resolveDenialCode to return Optional<String>.
    */
    private void ensureDenialIdColumnExists() { /* no-op placeholder to highlight the note above */ }
}
