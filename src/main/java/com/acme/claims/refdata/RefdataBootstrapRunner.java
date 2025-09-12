package com.acme.claims.refdata;

import com.acme.claims.refdata.config.RefdataBootstrapProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@Order(10)
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "claims.refdata.bootstrap", name = "enabled", havingValue = "true")
public class RefdataBootstrapRunner implements ApplicationRunner {

    private final RefdataCsvLoader loader;
    private final RefdataBootstrapProperties props;

    @Override
    public void run(ApplicationArguments args) {
        log.info("Refdata bootstrap starting. source={} strict={} delimiter='{}' batch={}",
                props.getLocation(), props.isStrict(), props.getDelimiter(), props.getBatchSize());
        int total = 0;
        total += loader.loadPayers();
        total += loader.loadFacilities();
        total += loader.loadProviders();
        total += loader.loadClinicians();
        total += loader.loadActivityCodes();
        total += loader.loadDiagnosisCodes();
        total += loader.loadDenialCodes();
        total += loader.loadContractPackages();
        log.info("Refdata bootstrap finished. total rows affected={}", total);
    }
}
