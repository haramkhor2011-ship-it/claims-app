// src/main/java/com/acme/claims/soap/db/ToggleRepo.java
package com.acme.claims.soap.db;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@RequiredArgsConstructor
public class ToggleRepo {
    private final JdbcTemplate jdbc;

    public boolean isEnabled(String code) {
        Boolean v = jdbc.query("select enabled from claims.integration_toggle where code=?",
                ps -> ps.setString(1, code),
                rs -> rs.next() ? rs.getBoolean(1) : Boolean.FALSE);
        return Boolean.TRUE.equals(v);
    }

    public void setEnabled(String code, boolean enabled) {
        jdbc.update("""
      insert into claims.integration_toggle(code, enabled) values(?, ?)
      on conflict(code) do update set enabled=excluded.enabled, updated_at=now()
      """, code, enabled);
    }
}
