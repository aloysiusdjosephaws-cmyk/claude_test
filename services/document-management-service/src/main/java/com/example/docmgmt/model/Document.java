package com.example.docmgmt.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Table(name = "documents")
@Data
public class Document {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "app_id", nullable = false, length = 50)
    private String appId;

    @Column(name = "key_id", length = 100)
    private String keyId;

    @Column(name = "doc_name", nullable = false, length = 255)
    private String docName;

    @Column(length = 255)
    private String description;

    @Column(name = "group_name", length = 100)
    private String groupName;

    @Column(length = 20)
    private String extension;

    @Column(name = "content_type", nullable = false, length = 100)
    private String contentType;

    @Column(name = "file_size", nullable = false)
    private Long fileSize;

    /** Y = only the uploader (AppManager) can view; N = all assigned users can view */
    @Column(name = "file_filter", nullable = false, length = 1)
    private String fileFilter = "N";

    @Column(name = "uploaded_by", nullable = false, length = 50)
    private String uploadedBy;

    @Column(name = "upload_date", updatable = false)
    private LocalDateTime uploadDate;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @Column(name = "is_deleted", nullable = false)
    private boolean deleted = false;

    @Lob
    @Column(name = "data", nullable = false)
    private byte[] data;

    @PrePersist
    protected void onCreate() {
        uploadDate = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
