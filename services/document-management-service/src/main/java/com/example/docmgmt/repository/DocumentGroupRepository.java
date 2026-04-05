package com.example.docmgmt.repository;

import com.example.docmgmt.model.DocumentGroup;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface DocumentGroupRepository extends JpaRepository<DocumentGroup, Long> {
    List<DocumentGroup> findByAppId(String appId);
    Optional<DocumentGroup> findByAppIdAndGroupName(String appId, String groupName);
}
