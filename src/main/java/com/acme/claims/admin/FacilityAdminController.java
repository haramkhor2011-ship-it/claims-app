package com.acme.claims.admin;

import com.acme.claims.security.ame.ReencryptJob;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/admin/facilities")
@RequiredArgsConstructor
public class FacilityAdminController {

    private final FacilityAdminService svc;
    private final ReencryptJob reencrypt;

    @PostMapping
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<?> createOrUpdate(@RequestBody FacilityAdminService.FacilityDto dto) {
        svc.upsert(dto);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/{code}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<FacilityAdminService.FacilityView> get(@PathVariable String code) {
        return ResponseEntity.ok(svc.get(code));
    }

    @PatchMapping("/{code}/activate")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<?> activate(@PathVariable String code, @RequestParam boolean active) {
        svc.activate(code, active);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/ame/rotate")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<?> rotate() {
        int updated = reencrypt.reencryptAllIfNeeded();
        return ResponseEntity.ok().body("{\"updated\":"+updated+"}");
    }
}
