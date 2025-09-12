// FILE: src/main/java/com/acme/claims/ingestion/mapper/MapperConfig.java
// Version: v1.0.0
package com.acme.claims.mapper;


import org.mapstruct.ReportingPolicy;
import org.mapstruct.MapperConfig;

@MapperConfig(
        componentModel = "spring",
        unmappedTargetPolicy = ReportingPolicy.ERROR // fail-fast if a persisted field is missed
)
public interface MapStructCentralConfig  {}
