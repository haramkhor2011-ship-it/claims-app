package com.acme.claims.refdata.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "claims.refdata")
public class RefDataProperties {
    /** When true, resolver upserts missing codes; when false, only audits and returns empty. */
    private boolean autoInsert = true;
    public boolean isAutoInsert() { return autoInsert; }
    public void setAutoInsert(boolean autoInsert) { this.autoInsert = autoInsert; }
}
