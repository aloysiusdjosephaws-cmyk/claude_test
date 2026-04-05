package com.example.docmgmt.controller;

import com.example.docmgmt.model.HelpDocument;
import com.example.docmgmt.service.HelpService;
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

@RestController
@RequestMapping("/help")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class HelpController {

    private final HelpService helpService;

    @GetMapping("/{screenName}")
    public ResponseEntity<byte[]> getHelp(@PathVariable String screenName) {
        return helpService.findByScreenName(screenName)
                .map(doc -> ResponseEntity.ok()
                        .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + doc.getDocName() + "\"")
                        .contentType(MediaType.parseMediaType(doc.getContentType()))
                        .body(doc.getData()))
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{screenName}")
    public ResponseEntity<?> uploadHelp(@PathVariable String screenName,
                                        @RequestParam("file") MultipartFile file,
                                        Authentication auth) {
        String role = auth == null ? "" : auth.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .findFirst().orElse("").replace("ROLE_", "");
        if (!"SUPER_USER".equals(role)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body("{\"error\":\"Only SUPER_USER can update help documents\"}");
        }
        try {
            return ResponseEntity.ok(helpService.save(screenName, file));
        } catch (IOException e) {
            return ResponseEntity.status(500).body("{\"error\":\"Upload failed\"}");
        }
    }
}
