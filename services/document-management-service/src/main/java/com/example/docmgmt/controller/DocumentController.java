package com.example.docmgmt.controller;

import com.example.docmgmt.dto.DocumentDto;
import com.example.docmgmt.dto.UpdateDocumentRequest;
import com.example.docmgmt.model.Document;
import com.example.docmgmt.service.DocumentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/documents")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class DocumentController {

    private final DocumentService documentService;

    @PostMapping("/upload")
    public ResponseEntity<?> upload(
            @RequestParam("file") MultipartFile file,
            @RequestParam("appId") String appId,
            @RequestParam(value = "description", required = false) String description,
            @RequestParam(value = "groupName", required = false) String groupName,
            @RequestParam(value = "keyId", required = false) String keyId,
            @RequestParam(value = "fileFilter", defaultValue = "N") String fileFilter) {
        try {
            DocumentDto dto = documentService.upload(file, appId, description, groupName, keyId, fileFilter);
            return ResponseEntity.status(HttpStatus.CREATED).body(dto);
        } catch (IOException e) {
            return ResponseEntity.status(500).body("{\"error\":\"Upload failed: " + e.getMessage() + "\"}");
        }
    }

    @GetMapping
    public ResponseEntity<List<DocumentDto>> list(@RequestParam String appId) {
        return ResponseEntity.ok(documentService.listForManager(appId));
    }

    @GetMapping("/{id}")
    public ResponseEntity<DocumentDto> getOne(@PathVariable Long id) {
        return documentService.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}/download")
    public ResponseEntity<byte[]> download(@PathVariable Long id, Authentication auth) {
        String currentUserId = (String) auth.getPrincipal();
        String role = auth.getAuthorities().stream().map(GrantedAuthority::getAuthority)
                .findFirst().orElse("").replace("ROLE_", "");

        return documentService.findByIdRaw(id)
                .filter(doc -> "N".equals(doc.getFileFilter()) || doc.getUploadedBy().equals(currentUserId))
                .map(doc -> ResponseEntity.ok()
                        .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + doc.getDocName() + "\"")
                        .contentType(MediaType.parseMediaType(doc.getContentType()))
                        .body(doc.getData()))
                .orElse(ResponseEntity.status(HttpStatus.FORBIDDEN).build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<DocumentDto> update(@PathVariable Long id,
                                              @RequestBody UpdateDocumentRequest req) {
        return ResponseEntity.ok(documentService.update(id, req));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        documentService.delete(id);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/search")
    public ResponseEntity<List<DocumentDto>> search(
            @RequestParam String appId,
            @RequestParam(required = false) String keyId,
            @RequestParam(required = false) String docName,
            @RequestParam(required = false) String groupName) {
        return ResponseEntity.ok(documentService.search(appId, keyId, docName, groupName));
    }
}
