package com.example.audit.controller;

import com.example.audit.dto.AuditEventDto;
import com.example.audit.model.AuditEvent;
import com.example.audit.service.AuditService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

@RestController
@RequestMapping("/audit")
@RequiredArgsConstructor
public class AuditController {

    private final AuditService auditService;

    /** Called by other services with X-Internal-Key header (validated in SecurityConfig). */
    @PostMapping("/events")
    public ResponseEntity<AuditEvent> recordEvent(@RequestBody AuditEventDto dto) {
        AuditEvent saved = auditService.save(dto);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    /** Query events — requires JWT with role SUPER_USER or PROJECT_OFFICER. */
    @GetMapping("/events")
    public ResponseEntity<Page<AuditEvent>> queryEvents(
            @RequestParam(required = false) String actorUserId,
            @RequestParam(required = false) String eventType,
            @RequestParam(required = false) String appId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime toDate,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(auditService.findAll(actorUserId, eventType, appId, fromDate, toDate, page, size));
    }

    @GetMapping("/events/{id}")
    public ResponseEntity<AuditEvent> getEvent(@PathVariable Long id) {
        return auditService.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}
