## Dependency Upgrade Playbook

Purpose: keep dependencies current and secure with minimal risk and predictable cadence.

### Cadence
- Monthly: automated PRs for safe patch/minor updates.
- Quarterly: review major updates behind feature flags/branches.
- Ad hoc: hotfix response for critical CVEs.

### Roles
- Automation: Renovate/Dependabot creates PRs with changelogs.
- Developer: reviews impact, merges after validation.
- CI: runs vulnerability scan and full tests on every PR.

### Tooling
1. Maven Versions Plugin (inventory updates)
   - Command:
     - Windows PowerShell:
       - `mvn "-Denforcer.skip=true" versions:display-dependency-updates versions:display-plugin-updates -DallowSnapshots=false`
   - Output: list of newer dependency and plugin versions.

2. OWASP Dependency-Check (vulnerability scan)
   - Requires NVD API key due to rate limiting.
   - Command (in CI):
     - `mvn org.owasp:dependency-check-maven:9.2.0:check -Dnvd.apiKey=${NVD_API_KEY} -Dformat=HTML -DfailOnError=false`
   - Artifact: `target/dependency-check-report.html` published from CI.

3. Optional: Snyk (or OSS Index) for additional coverage
   - Run in CI for PRs and default branch.

### Process per Cycle
1. Discovery
   - Run Versions Plugin; capture output as a CI artifact.
   - Run OWASP scan; capture HTML report.
2. Selection
   - Approve patch updates by default.
   - Minor updates when semver indicates compatibility and release notes show no breaking changes.
   - Major updates isolated per area (e.g., WireMock 3 migration in tests).
3. Implementation
   - Create branch PR(s) grouped by risk area:
     - Runtime patch bumps (e.g., `httpclient5`, `postgresql`, `commons-io`).
     - Documentation/UI libs (e.g., `springdoc`).
     - Test-only libs (e.g., WireMock, Mockito, Awaitility, Testcontainers BOM).
   - Update versions and fix compile issues locally.
4. Validation
   - Build and test: `mvn -U clean verify` (no `-DskipTests`).
   - Run integration/E2E profile as needed: `mvn -Pe2e verify`.
   - Smoke test core workflows.
5. Rollout
   - Merge PR after approvals and green CI.
   - Release notes documented.

### Best Practices
- Prefer BOMs (Spring Boot, Testcontainers) to align transitive versions.
- Avoid version ranges/LATEST; pin explicit versions, or defer to BOM.
- Use correct scopes (`test`, `provided`, etc.) to minimize attack surface.
- Exclude unused and unnecessary transitives (`mvn dependency:analyze`).
- Keep Java toolchain and Maven plugins updated regularly.

### Suggested CI YAML Snippet (conceptual)
```yaml
jobs:
  deps-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
          cache: maven
      - name: List updates
        run: mvn "-Denforcer.skip=true" versions:display-dependency-updates versions:display-plugin-updates -DallowSnapshots=false
      - name: OWASP Dependency-Check
        env:
          NVD_API_KEY: ${{ secrets.NVD_API_KEY }}
        run: |
          mvn -q org.owasp:dependency-check-maven:9.2.0:check -Dnvd.apiKey=${NVD_API_KEY} -Dformat=HTML -DfailOnError=false
      - name: Build and test
        run: mvn -U clean verify
      - name: Upload OWASP report
        uses: actions/upload-artifact@v4
        with:
          name: dependency-check-report
          path: target/dependency-check-report.html
```

### Focus Areas for This Repo
- Keep within Spring Boot 3.3.x until a deliberate 3.4 migration plan.
- Patch updates for: `jjwt`, `postgresql`, `httpclient5`, `commons-io`, `commons-csv`, `springdoc`.
- Migrate tests from `wiremock-jre8` (2.x) to WireMock 3.x when convenient.

### Acceptance Criteria for Each Upgrade PR
- Compiles with no new warnings/errors.
- Unit and integration tests pass.
- No breaking API behavior changes.
- OWASP report shows equal or fewer issues.
- Release notes linked in PR.






