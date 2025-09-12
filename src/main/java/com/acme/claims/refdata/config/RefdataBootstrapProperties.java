package com.acme.claims.refdata.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

@Getter @Setter
@ConfigurationProperties(prefix = "claims.refdata.bootstrap")
public class RefdataBootstrapProperties {
    /** Enable/disable bootstrap on startup (default false) */
    private boolean enabled = false;
    /** Strict mode: missing file or bad headers cause startup failure (default false) */
    private boolean strict = false;
    /** Location of CSVs: classpath:refdata/ or file:/opt/refdata/ */
    private String location = "classpath:refdata/";
    /** CSV delimiter: default ',' */
    private char delimiter = ',';
    /** Batch size for JDBC batchUpdate */
    private int batchSize = 500;
    /** Filenames that must exist in strict mode; otherwise optional */
    private List<String> requiredFiles = List.of(
            "payers.csv",
            "facilities.csv",
            "providers.csv",
            "clinicians.csv",
            "activity_codes.csv",
            "diagnosis_codes.csv",
            "denial_codes.csv",
            "contract_packages.csv"
    );
}
