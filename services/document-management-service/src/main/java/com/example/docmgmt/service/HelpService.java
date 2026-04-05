package com.example.docmgmt.service;

import com.example.docmgmt.model.HelpDocument;
import com.example.docmgmt.repository.HelpDocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class HelpService {

    private final HelpDocumentRepository helpRepository;

    public Optional<HelpDocument> findByScreenName(String screenName) {
        return helpRepository.findByScreenName(screenName);
    }

    public HelpDocument save(String screenName, MultipartFile file) throws IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String updatedBy = auth != null ? (String) auth.getPrincipal() : "system";

        HelpDocument help = helpRepository.findByScreenName(screenName)
                .orElse(new HelpDocument());
        help.setScreenName(screenName);
        help.setDocName(file.getOriginalFilename() != null ? file.getOriginalFilename() : screenName + "-help");
        help.setContentType(file.getContentType() != null ? file.getContentType() : "application/octet-stream");
        help.setData(file.getBytes());
        help.setUpdatedBy(updatedBy);
        return helpRepository.save(help);
    }
}
