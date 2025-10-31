package com.acme.claims.ingestion.monitor;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Periodic, feature-gated KPI logger that reads from claims.v_ingestion_kpis
 * and emits a concise summary. This does not modify pipeline behavior.
 */
@Slf4j
@Component
@Profile("soap")
@RequiredArgsConstructor
public class IngestionKpiLogger {

    private final JdbcTemplate jdbc;

    @Value("${claims.monitor.kpi.enabled:false}")
    boolean enabled;

    // Default every 10 minutes; start with 1 minute delay
    @Scheduled(fixedDelayString = "${claims.monitor.kpi.fixedDelayMs:600000}", initialDelay = 60000)
    public void logKpis() {
        if (!enabled) return;
        doLog();
    }

    /** Allows on-demand KPI snapshot logging after a poll cycle. */
    public void logKpisImmediate() {
        if (!enabled) return;
        doLog();
    }

    private void doLog() {
        try {
            // Latest hour bucket summary from view
            String sql = """
                SELECT hour_bucket, files_total, files_ok, files_fail, files_already,
                       parsed_claims, persisted_claims,
                       parsed_activities, persisted_activities,
                       parsed_remit_claims, persisted_remit_claims,
                       parsed_remit_activities, persisted_remit_activities,
                       files_verified
                  FROM claims.v_ingestion_kpis
                 ORDER BY hour_bucket DESC
                 LIMIT 1
            """;
            jdbc.query(sql, rs -> {
                String hb = rs.getTimestamp("hour_bucket").toInstant().toString();
                long filesTotal = rs.getLong("files_total");
                long filesOk = rs.getLong("files_ok");
                long filesFail = rs.getLong("files_fail");
                long filesAlready = rs.getLong("files_already");
                long parsedClaims = rs.getLong("parsed_claims");
                long persistedClaims = rs.getLong("persisted_claims");
                long parsedActs = rs.getLong("parsed_activities");
                long persistedActs = rs.getLong("persisted_activities");
                long parsedRemitClaims = rs.getLong("parsed_remit_claims");
                long persistedRemitClaims = rs.getLong("persisted_remit_claims");
                long parsedRemitActs = rs.getLong("parsed_remit_activities");
                long persistedRemitActs = rs.getLong("persisted_remit_activities");
                long filesVerified = rs.getLong("files_verified");

                log.info("INGESTION_KPI hour={} files_total={} files_ok={} files_fail={} files_already={} files_verified={} " +
                                "parsed_claims={} persisted_claims={} parsed_activities={} persisted_activities={} " +
                                "parsed_remit_claims={} persisted_remit_claims={} parsed_remit_activities={} persisted_remit_activities={}",
                        hb, filesTotal, filesOk, filesFail, filesAlready, filesVerified,
                        parsedClaims, persistedClaims, parsedActs, persistedActs,
                        parsedRemitClaims, persistedRemitClaims, parsedRemitActs, persistedRemitActs);
            });
        } catch (Exception e) {
            log.warn("Failed to log ingestion KPIs: {}", e.getMessage());
        }
    }
}


