package com.acme.claims.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

/**
 * Diagnostic utility to check materialized view status and base table data.
 * Run with: mvn spring-boot:run -Dspring-boot.run.arguments="--diagnostic.mv.enabled=true"
 */
@Component
@ConditionalOnProperty(name = "diagnostic.mv.enabled", havingValue = "true")
public class MaterializedViewDiagnostic implements CommandLineRunner {
    
    private static final Logger log = LoggerFactory.getLogger(MaterializedViewDiagnostic.class);
    
    private final JdbcTemplate jdbcTemplate;
    
    public MaterializedViewDiagnostic(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }
    
    @Override
    public void run(String... args) {
        log.info("========================================");
        log.info("MATERIALIZED VIEW DIAGNOSTIC");
        log.info("========================================");
        
        checkMaterializedViewsExist();
        checkMaterializedViewCounts();
        checkBaseTableCounts();
        checkReferenceDataCounts();
        checkJoinConditions();
        checkRefIdPopulation();
        sampleMaterializedViewData();
        
        log.info("========================================");
        log.info("DIAGNOSTIC COMPLETE");
        log.info("========================================");
    }
    
    private void checkMaterializedViewsExist() {
        log.info("\n=== 1. Check Materialized Views Existence ===");
        try {
            String sql = """
                SELECT 
                    schemaname,
                    matviewname,
                    pg_size_pretty(pg_total_relation_size(schemaname||'.'||matviewname)) as size
                FROM pg_matviews 
                WHERE schemaname = 'claims' AND matviewname LIKE 'mv_%'
                ORDER BY matviewname
                """;
            
            List<Map<String, Object>> result = jdbcTemplate.queryForList(sql);
            if (result.isEmpty()) {
                log.warn("NO MATERIALIZED VIEWS FOUND!");
            } else {
                result.forEach(row -> 
                    log.info("  {} - Size: {}", row.get("matviewname"), row.get("size"))
                );
            }
        } catch (Exception e) {
            log.error("Error checking materialized views: {}", e.getMessage());
        }
    }
    
    private void checkMaterializedViewCounts() {
        log.info("\n=== 2. Materialized View Row Counts ===");
        
        String[] mvNames = {
            "mv_balance_amount_summary",
            "mv_remittance_advice_summary",
            "mv_doctor_denial_summary",
            "mv_claims_monthly_agg",
            "mv_claim_details_complete",
            "mv_resubmission_cycles",
            "mv_remittances_resubmission_activity_level",
            "mv_rejected_claims_summary",
            "mv_claim_summary_payerwise",
            "mv_claim_summary_encounterwise"
        };
        
        for (String mvName : mvNames) {
            try {
                Long count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM claims." + mvName, 
                    Long.class
                );
                log.info("  {} : {} rows", mvName, count);
                if (count == 0) {
                    log.warn("    ^^^ EMPTY MATERIALIZED VIEW!");
                }
            } catch (Exception e) {
                log.error("  {} : ERROR - {}", mvName, e.getMessage());
            }
        }
    }
    
    private void checkBaseTableCounts() {
        log.info("\n=== 3. Base Table Row Counts ===");
        
        String[] tables = {
            "claim_key", "claim", "encounter", "activity",
            "remittance_claim", "remittance_activity", 
            "claim_event", "claim_status_timeline"
        };
        
        for (String table : tables) {
            try {
                Long count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM claims." + table, 
                    Long.class
                );
                log.info("  {} : {} rows", table, count);
                if (count == 0) {
                    log.warn("    ^^^ EMPTY BASE TABLE - This is likely the root cause!");
                }
            } catch (Exception e) {
                log.error("  {} : ERROR - {}", table, e.getMessage());
            }
        }
    }
    
    private void checkReferenceDataCounts() {
        log.info("\n=== 4. Reference Data Row Counts ===");
        
        String[] refTables = {
            "provider", "payer", "facility", "clinician", "denial_code"
        };
        
        for (String table : refTables) {
            try {
                Long count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM claims_ref." + table, 
                    Long.class
                );
                log.info("  {} : {} rows", table, count);
            } catch (Exception e) {
                log.error("  {} : ERROR - {}", table, e.getMessage());
            }
        }
    }
    
    private void checkJoinConditions() {
        log.info("\n=== 5. JOIN Test: claim_key to claim ===");
        try {
            String sql = """
                SELECT 
                    COUNT(DISTINCT ck.id) as claim_keys,
                    COUNT(DISTINCT c.id) as claims_joined
                FROM claims.claim_key ck
                LEFT JOIN claims.claim c ON c.claim_key_id = ck.id
                """;
            
            Map<String, Object> result = jdbcTemplate.queryForMap(sql);
            log.info("  Claim Keys: {}", result.get("claim_keys"));
            log.info("  Claims Joined: {}", result.get("claims_joined"));
            
            if (!result.get("claim_keys").equals(result.get("claims_joined"))) {
                log.warn("  ^^^ MISMATCH - Some claim_keys don't have matching claims!");
            }
        } catch (Exception e) {
            log.error("Error checking joins: {}", e.getMessage());
        }
    }
    
    private void checkRefIdPopulation() {
        log.info("\n=== 6. Reference ID Population Check ===");
        try {
            String sql = """
                SELECT 
                    'claim.provider_ref_id' as field,
                    COUNT(*) as total,
                    COUNT(provider_ref_id) as populated,
                    COUNT(*) - COUNT(provider_ref_id) as nulls
                FROM claims.claim
                """;
            
            Map<String, Object> result = jdbcTemplate.queryForMap(sql);
            log.info("  {} - Total: {}, Populated: {}, Nulls: {}", 
                result.get("field"), result.get("total"), result.get("populated"), result.get("nulls"));
                
            // Check payer_ref_id
            sql = """
                SELECT 
                    COUNT(*) as total,
                    COUNT(payer_ref_id) as populated,
                    COUNT(*) - COUNT(payer_ref_id) as nulls
                FROM claims.claim
                """;
            result = jdbcTemplate.queryForMap(sql);
            log.info("  claim.payer_ref_id - Total: {}, Populated: {}, Nulls: {}", 
                result.get("total"), result.get("populated"), result.get("nulls"));
            
        } catch (Exception e) {
            log.error("Error checking ref_ids: {}", e.getMessage());
        }
    }
    
    private void sampleMaterializedViewData() {
        log.info("\n=== 7. Sample Data from mv_balance_amount_summary ===");
        try {
            String sql = "SELECT * FROM claims.mv_balance_amount_summary LIMIT 3";
            List<Map<String, Object>> result = jdbcTemplate.queryForList(sql);
            
            if (result.isEmpty()) {
                log.warn("  NO DATA IN MATERIALIZED VIEW!");
            } else {
                result.forEach(row -> {
                    log.info("  Sample Row:");
                    log.info("    claim_key_id: {}", row.get("claim_key_id"));
                    log.info("    claim_id: {}", row.get("claim_id"));
                    log.info("    pending_amount: {}", row.get("pending_amount"));
                });
            }
        } catch (Exception e) {
            log.error("Error sampling data: {}", e.getMessage());
        }
    }
}

