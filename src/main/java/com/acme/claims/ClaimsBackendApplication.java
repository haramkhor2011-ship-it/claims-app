package com.acme.claims;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
@ConfigurationPropertiesScan(basePackages = "com.acme.claims")
public class ClaimsBackendApplication {
	public static void main(String[] args) {
		SpringApplication.run(ClaimsBackendApplication.class, args);
	}
}
