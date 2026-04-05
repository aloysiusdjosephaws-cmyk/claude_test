package com.example.appmgmt.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Table(name = "app_manager_assignments",
    uniqueConstraints = @UniqueConstraint(columnNames = {"app_id", "manager_user_id"}))
@Data
public class AppManagerAssignment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "app_id", nullable = false, length = 50)
    private String appId;

    @Column(name = "manager_user_id", nullable = false, length = 50)
    private String managerUserId;

    @Column(name = "assigned_by", nullable = false, length = 50)
    private String assignedBy;

    @Column(name = "assigned_at", updatable = false)
    private LocalDateTime assignedAt;

    @PrePersist
    protected void onCreate() {
        assignedAt = LocalDateTime.now();
    }
}
