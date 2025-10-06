package com.acme.claims.refdata;

import com.acme.claims.refdata.config.RefdataBootstrapProperties;
import com.acme.claims.refdata.entity.BootstrapStatus;
import com.acme.claims.refdata.repository.BootstrapStatusRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;

@Slf4j
@Component
@Order(10)
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "claims.refdata.bootstrap", name = "enabled", havingValue = "true")
public class RefdataBootstrapRunner implements ApplicationRunner {

    private static final String BOOTSTRAP_NAME = "refdata_csv_loader";
    private static final String BOOTSTRAP_VERSION = "1.0";

    private final RefdataCsvLoader loader;
    private final RefdataBootstrapProperties props;
    private final BootstrapStatusRepository bootstrapStatusRepository;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        // Check if bootstrap has already been completed
        if (bootstrapStatusRepository.isBootstrapCompleted(BOOTSTRAP_NAME)) {
            log.info("Refdata bootstrap already completed. Skipping CSV loading. bootstrap={} version={}", 
                    BOOTSTRAP_NAME, BOOTSTRAP_VERSION);
            return;
        }

        log.info("Refdata bootstrap starting. source={} strict={} delimiter='{}' batch={} bootstrap={} version={}",
                props.getLocation(), props.isStrict(), props.getDelimiter(), props.getBatchSize(), 
                BOOTSTRAP_NAME, BOOTSTRAP_VERSION);
        
        try {
            int total = 0;
            total += loader.loadPayers();
            total += loader.loadFacilities();
            total += loader.loadProviders();
            total += loader.loadClinicians();
            total += loader.loadActivityCodes();
            total += loader.loadDiagnosisCodes();
            total += loader.loadDenialCodes();
            total += loader.loadContractPackages();
            
            // Mark bootstrap as completed
            markBootstrapCompleted(total);
            
            log.info("Refdata bootstrap completed successfully. total rows affected={} bootstrap={} version={}", 
                    total, BOOTSTRAP_NAME, BOOTSTRAP_VERSION);
                    
        } catch (Exception e) {
            log.error("Refdata bootstrap failed. bootstrap={} version={}", BOOTSTRAP_NAME, BOOTSTRAP_VERSION, e);
            throw e; // Re-throw to fail application startup
        }
    }

    private void markBootstrapCompleted(int totalRows) {
        BootstrapStatus status = BootstrapStatus.builder()
                .bootstrapName(BOOTSTRAP_NAME)
                .completedAt(OffsetDateTime.now())
                .version(BOOTSTRAP_VERSION)
                .build();
        
        bootstrapStatusRepository.save(status);
        log.info("Bootstrap status marked as completed. bootstrap={} version={} rows={}", 
                BOOTSTRAP_NAME, BOOTSTRAP_VERSION, totalRows);
    }
}
