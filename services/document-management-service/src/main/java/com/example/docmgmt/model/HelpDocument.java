package com.example.docmgmt.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Table(name = "help_documents")
@Data
public class HelpDocument {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** SUPER_USER | PROJECT_OFFICER | APP_MANAGER | APP_USER */
    @Column(name = "screen_name", unique = true, nullable = false, length = 50)
    private String screenName;

    @Column(name = "doc_name", nullable = false, length = 255)
    private String docName;

    @Column(name = "content_type", nullable = false, length = 100)
    private String contentType;

    @Lob
    @Column(name = "data", nullable = false)
    private byte[] data;

    @Column(name = "updated_by", nullable = false, length = 50)
    private String updatedBy;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
