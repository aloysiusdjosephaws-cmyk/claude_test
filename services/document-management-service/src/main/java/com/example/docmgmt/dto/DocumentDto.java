package com.example.docmgmt.dto;

import com.example.docmgmt.model.Document;
import lombok.Data;
import java.time.LocalDateTime;

@Data
public class DocumentDto {
    private Long id;
    private String appId;
    private String keyId;
    private String docName;
    private String description;
    private String groupName;
    private String extension;
    private String contentType;
    private Long fileSize;
    private String fileFilter;
    private String uploadedBy;
    private LocalDateTime uploadDate;
    private LocalDateTime updatedAt;
    private boolean deleted;

    public static DocumentDto from(Document doc) {
        DocumentDto dto = new DocumentDto();
        dto.setId(doc.getId());
        dto.setAppId(doc.getAppId());
        dto.setKeyId(doc.getKeyId());
        dto.setDocName(doc.getDocName());
        dto.setDescription(doc.getDescription());
        dto.setGroupName(doc.getGroupName());
        dto.setExtension(doc.getExtension());
        dto.setContentType(doc.getContentType());
        dto.setFileSize(doc.getFileSize());
        dto.setFileFilter(doc.getFileFilter());
        dto.setUploadedBy(doc.getUploadedBy());
        dto.setUploadDate(doc.getUploadDate());
        dto.setUpdatedAt(doc.getUpdatedAt());
        dto.setDeleted(doc.isDeleted());
        return dto;
    }
}
