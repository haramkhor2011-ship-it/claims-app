package com.acme.claims.monitoring;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;

/**
 * Configuration for database monitoring components
 */
@Configuration
@Slf4j
@ConditionalOnProperty(name = "claims.monitoring.database.enabled", havingValue = "true", matchIfMissing = true)
public class DatabaseMonitoringConfiguration {
}
