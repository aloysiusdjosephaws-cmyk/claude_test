package com.example.audit.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Table(name = "audit_events", indexes = {
    @Index(name = "idx_audit_actor", columnList = "actor_user_id"),
    @Index(name = "idx_audit_app", columnList = "app_id"),
    @Index(name = "idx_audit_type", columnList = "event_type"),
    @Index(name = "idx_audit_time", columnList = "occurred_at")
})
@Data
public class AuditEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "event_type", nullable = false, length = 50)
    private String eventType;

    @Column(name = "actor_user_id", nullable = false, length = 50)
    private String actorUserId;

    @Column(name = "actor_role", nullable = false, length = 30)
    private String actorRole;

    @Column(name = "target_type", length = 50)
    private String targetType;

    @Column(name = "target_id", length = 100)
    private String targetId;

    @Column(name = "app_id", length = 50)
    private String appId;

    @Column(name = "payload", length = 2000)
    private String payload;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "occurred_at", nullable = false, updatable = false)
    private LocalDateTime occurredAt;

    @PrePersist
    protected void onCreate() {
        occurredAt = LocalDateTime.now();
    }
}
