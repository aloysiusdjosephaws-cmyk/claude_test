package com.example.docmgmt.repository;

import com.example.docmgmt.model.HelpDocument;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface HelpDocumentRepository extends JpaRepository<HelpDocument, Long> {
    Optional<HelpDocument> findByScreenName(String screenName);
}
