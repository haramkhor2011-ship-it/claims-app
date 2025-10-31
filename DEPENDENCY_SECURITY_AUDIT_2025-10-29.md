## Dependency Security Audit (2025-10-29)

Scope: `claims-backend` Maven project `pom.xml` at the repo root.

### Summary
- Objective: identify vulnerable/outdated dependencies and recommend safe upgrades following best practices.
- Tools attempted: Maven Versions Plugin (listing updates), OWASP Dependency-Check. The OWASP scan requires an NVD API key in this environment; see Actions below to enable in CI.

### Key Recommendations (high-signal)
- **Stay on Spring Boot 3.3.x and upgrade to latest patch in 3.3 line** once validated (managed dependencies get patched transitively).
- **Pin explicit versions only where necessary;** lean on the Spring Boot BOM for alignment. Reduce direct version pins where Boot manages them.
- **Prioritize patch upgrades** for explicitly versioned libs below; most are safe, low risk:
  - `io.jsonwebtoken:jjwt-*` 0.12.3 → consider 0.12.x latest (0.12.5+)
  - `org.postgresql:postgresql` 42.7.3 → 42.7.x latest (e.g., 42.7.4+)
  - `org.apache.httpcomponents.client5:httpclient5` 5.3.1 → 5.3.x latest (5.3.2+)
  - `org.json:json` 20240303 → latest release or replace with Jackson-only
  - `commons-io:commons-io` 2.15.1 → 2.16.x latest
  - `org.apache.commons:commons-csv` 1.11.0 → 1.11.x latest
  - `org.springdoc:springdoc-openapi-starter-webmvc-ui` 2.2.0 → 2.6.x latest (compatible with Boot 3.3)
  - `com.github.tomakehurst:wiremock-jre8` 2.35.1 (test) → migrate to WireMock 3.x (new coordinates)
  - `org.mockito:mockito-inline` 5.2.0 (test) → latest 5.x/6.x compatible
  - `org.awaitility:awaitility` 4.2.0 (test) → 4.2.x latest

Notes: Exact latest patch versions should be resolved during execution using the Maven Versions Plugin in CI/CD to avoid drift.

### Detected Dependencies (from pom.xml)

Managed by Spring Boot 3.3.2 BOM unless version is explicitly set.

Runtime and compile scope:
- org.springframework.boot:spring-boot-starter-web (BOM)
- org.springframework.boot:spring-boot-starter-validation (BOM)
- org.springframework.boot:spring-boot-starter-security (BOM)
- org.springframework.boot:spring-boot-starter-oauth2-resource-server (BOM)
- io.jsonwebtoken:jjwt-api:0.12.3
- io.jsonwebtoken:jjwt-impl:0.12.3 (runtime)
- io.jsonwebtoken:jjwt-jackson:0.12.3 (runtime)
- org.springframework.boot:spring-boot-starter-data-jpa (BOM)
- org.postgresql:postgresql:42.7.3
- org.springframework.boot:spring-boot-starter-data-redis (BOM)
- com.github.ben-manes.caffeine:caffeine (BOM)
- org.springframework.boot:spring-boot-starter-cache (BOM)
- org.springframework.ws:spring-ws-core (BOM)
- org.springframework.ws:spring-ws-support (BOM)
- jakarta.xml.soap:jakarta.xml.soap-api:3.0.2
- com.sun.xml.messaging.saaj:saaj-impl:3.0.4
- org.apache.httpcomponents.client5:httpclient5:5.3.1
- org.json:json:20240303
- org.glassfish.jaxb:jaxb-runtime (BOM)
- com.fasterxml.jackson.dataformat:jackson-dataformat-xml (BOM)
- org.springframework.boot:spring-boot-starter-actuator (BOM)
- org.mapstruct:mapstruct:${mapstruct.version}
- org.projectlombok:lombok:${lombok.version} (provided)
- org.apache.commons:commons-csv:1.11.0
- commons-io:commons-io:2.15.1
- org.springdoc:springdoc-openapi-starter-webmvc-ui:2.2.0
- org.springframework:spring-aspects (BOM)

Test scope:
- org.springframework.boot:spring-boot-starter-test (BOM)
- org.springframework.security:spring-security-test (BOM)
- com.h2database:h2 (BOM)
- org.awaitility:awaitility:4.2.0
- org.mockito:mockito-inline:5.2.0
- org.testcontainers:postgresql (via Testcontainers BOM 1.20.2)
- com.github.tomakehurst:wiremock-jre8:2.35.1

Build plugins (relevant):
- spring-boot-maven-plugin (BOM)
- maven-surefire-plugin 3.2.5
- maven-failsafe-plugin 3.2.5 (profile `e2e`)
- maven-compiler-plugin (inherits version) with Java 21

### Risk Review and Notes
- Spring Boot 3.3.2: keep within 3.3.x; update to latest 3.3 patch to receive dependency alignment and security fixes across the stack.
- JWT (jjwt 0.12.3): no widely publicized critical CVEs in 0.12.x; stay current on 0.12.x for maintenance and security improvements.
- PostgreSQL JDBC 42.7.3: prefer latest 42.7.x for bug/security fixes.
- HttpClient5 5.3.1: prefer 5.3.2+ for fixes.
- org.json:json: periodically has bugfixes; consider minimizing usage in favor of Jackson to standardize.
- commons-io 2.15.1: move to 2.16.x to stay current.
- springdoc 2.2.0: upgrade to latest 2.x (2.6.x) for OpenAPI fixes and Boot 3.3 compatibility improvements.
- WireMock 2.x (jre8): project recommends migration to WireMock 3.x; test-only change but may require minor DSL updates.
- Testcontainers BOM 1.20.2: keep at latest 1.20.x; large benefits/bugfixes in recent patches.

### Actions to Enable Continuous, Accurate Scanning
1. Configure **OWASP Dependency-Check** with an NVD API key in CI to avoid NVD 403/404 throttling.
   - Provide `NVD_API_KEY` secret and run: `mvn org.owasp:dependency-check-maven:9.2.0:check -Dnvd.apiKey=${NVD_API_KEY} -Dformat=HTML -DfailOnError=false`.
   - Publish `target/dependency-check-report.html` as a build artifact.
2. Add **Maven Versions Plugin** step to list actionable updates each run:
   - `mvn -Denforcer.skip=true versions:display-dependency-updates versions:display-plugin-updates -DallowSnapshots=false`.
3. Optionally enable **Renovate** or **Dependabot** for PRs with curated upgrades.

### Proposed Next Patch Upgrades (non-breaking expectation)
These are expected to be low-risk patch/minor updates; validate with full build and tests:
- Spring Boot: 3.3.2 → latest 3.3.x
- jjwt: 0.12.3 → 0.12.x latest (api/impl/jackson trio)
- postgresql: 42.7.3 → 42.7.x latest
- httpclient5: 5.3.1 → 5.3.x latest
- org.json: 20240303 → latest release (or reduce usage)
- commons-io: 2.15.1 → 2.16.x latest
- commons-csv: 1.11.0 → 1.11.x latest
- springdoc-openapi: 2.2.0 → 2.6.x
- awaitility: 4.2.0 → 4.2.x latest (test)
- mockito-inline: 5.2.0 → latest 5.x/6.x compatible (test)
- wiremock: migrate from 2.x `wiremock-jre8` to 3.x (test)

### Verification Plan
1. Bump versions in a feature branch (start with patch upgrades only).
2. Run: `mvn -U -DskipTests=false clean verify` (CI should run full tests).
3. Smoke run locally (if applicable) focusing on security, auth, SOAP, and DB features.
4. Roll out in lower environments before prod.

### Appendix: Why OWASP needs an API key here
NVD enforces strict rate limits. Without an API key, scans can fail or return partial results. Configure once in CI and it will produce reliable reports on every run.






