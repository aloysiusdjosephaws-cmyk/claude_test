package com.example.docmgmt.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Table(name = "document_groups",
    uniqueConstraints = @UniqueConstraint(columnNames = {"app_id", "group_name"}))
@Data
public class DocumentGroup {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "app_id", nullable = false, length = 50)
    private String appId;

    @Column(name = "group_name", nullable = false, length = 100)
    private String groupName;

    @Column(name = "created_by", nullable = false, length = 50)
    private String createdBy;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
