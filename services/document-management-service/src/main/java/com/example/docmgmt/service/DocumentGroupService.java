package com.example.docmgmt.service;

import com.example.docmgmt.model.DocumentGroup;
import com.example.docmgmt.repository.DocumentGroupRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class DocumentGroupService {

    private final DocumentGroupRepository groupRepository;

    public List<DocumentGroup> findByAppId(String appId) {
        return groupRepository.findByAppId(appId);
    }

    public DocumentGroup create(String appId, String groupName) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String createdBy = (String) auth.getPrincipal();
        DocumentGroup group = new DocumentGroup();
        group.setAppId(appId);
        group.setGroupName(groupName);
        group.setCreatedBy(createdBy);
        return groupRepository.save(group);
    }

    public DocumentGroup update(Long id, String groupName) {
        DocumentGroup group = groupRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Group not found: " + id));
        group.setGroupName(groupName);
        return groupRepository.save(group);
    }
}
