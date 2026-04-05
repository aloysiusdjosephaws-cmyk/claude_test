package com.example.docmgmt.service;

import com.example.docmgmt.client.AuditClient;
import com.example.docmgmt.dto.AuditEventDto;
import com.example.docmgmt.dto.DocumentDto;
import com.example.docmgmt.dto.UpdateDocumentRequest;
import com.example.docmgmt.model.Document;
import com.example.docmgmt.repository.DocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DocumentService {

    private final DocumentRepository documentRepository;
    private final AuditClient auditClient;

    public DocumentDto upload(MultipartFile file, String appId, String description,
                              String groupName, String keyId, String fileFilter) throws IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String uploadedBy = (String) auth.getPrincipal();

        String originalName = file.getOriginalFilename() != null ? file.getOriginalFilename() : "unknown";
        String extension = originalName.contains(".")
                ? originalName.substring(originalName.lastIndexOf('.') + 1)
                : "";

        Document doc = new Document();
        doc.setAppId(appId);
        doc.setKeyId(keyId);
        doc.setDocName(originalName);
        doc.setDescription(description);
        doc.setGroupName(groupName);
        doc.setExtension(extension);
        doc.setContentType(file.getContentType() != null ? file.getContentType() : "application/octet-stream");
        doc.setFileSize(file.getSize());
        doc.setFileFilter(fileFilter != null ? fileFilter : "N");
        doc.setUploadedBy(uploadedBy);
        doc.setData(file.getBytes());

        Document saved = documentRepository.save(doc);
        emitAudit("DOCUMENT_UPLOADED", String.valueOf(saved.getId()), appId);
        return DocumentDto.from(saved);
    }

    public List<DocumentDto> listForManager(String appId) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String currentUserId = (String) auth.getPrincipal();

        return documentRepository.findByAppIdAndDeletedFalse(appId).stream()
                .filter(doc -> "N".equals(doc.getFileFilter()) || doc.getUploadedBy().equals(currentUserId))
                .map(DocumentDto::from)
                .collect(Collectors.toList());
    }

    public Optional<Document> findByIdRaw(Long id) {
        return documentRepository.findByIdAndDeletedFalse(id);
    }

    public Optional<DocumentDto> findById(Long id) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String currentUserId = (String) auth.getPrincipal();

        return documentRepository.findByIdAndDeletedFalse(id)
                .filter(doc -> "N".equals(doc.getFileFilter()) || doc.getUploadedBy().equals(currentUserId))
                .map(DocumentDto::from);
    }

    public DocumentDto update(Long id, UpdateDocumentRequest req) {
        Document doc = documentRepository.findByIdAndDeletedFalse(id)
                .orElseThrow(() -> new RuntimeException("Document not found: " + id));
        if (req.getDescription() != null) doc.setDescription(req.getDescription());
        if (req.getGroupName() != null) doc.setGroupName(req.getGroupName());
        Document saved = documentRepository.save(doc);
        emitAudit("DOCUMENT_UPDATED", String.valueOf(id), doc.getAppId());
        return DocumentDto.from(saved);
    }

    public void delete(Long id) {
        Document doc = documentRepository.findByIdAndDeletedFalse(id)
                .orElseThrow(() -> new RuntimeException("Document not found: " + id));
        doc.setDeleted(true);
        documentRepository.save(doc);
        emitAudit("DOCUMENT_DELETED", String.valueOf(id), doc.getAppId());
    }

    public List<DocumentDto> search(String appId, String keyId, String docName, String groupName) {
        return documentRepository.searchForUser(appId, keyId, docName, groupName)
                .stream().map(DocumentDto::from).collect(Collectors.toList());
    }

    private void emitAudit(String eventType, String targetId, String appId) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String actorId = auth != null ? (String) auth.getPrincipal() : "system";
        String actorRole = auth != null && !auth.getAuthorities().isEmpty()
                ? auth.getAuthorities().stream().map(GrantedAuthority::getAuthority)
                    .findFirst().orElse("").replace("ROLE_", "") : "";
        auditClient.recordEvent(AuditEventDto.builder()
                .eventType(eventType).actorUserId(actorId).actorRole(actorRole)
                .targetType("DOCUMENT").targetId(targetId).appId(appId).build());
    }
}
