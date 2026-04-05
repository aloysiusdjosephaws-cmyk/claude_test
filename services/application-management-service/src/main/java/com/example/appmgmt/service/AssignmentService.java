package com.example.appmgmt.service;

import com.example.appmgmt.client.AuditClient;
import com.example.appmgmt.dto.AuditEventDto;
import com.example.appmgmt.model.AppManagerAssignment;
import com.example.appmgmt.model.AppUserAssignment;
import com.example.appmgmt.repository.AppManagerAssignmentRepository;
import com.example.appmgmt.repository.AppUserAssignmentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class AssignmentService {

    private final AppManagerAssignmentRepository managerRepo;
    private final AppUserAssignmentRepository userRepo;
    private final AuditClient auditClient;

    public AppManagerAssignment assignManager(String appId, String managerUserId) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String actorId = (String) auth.getPrincipal();
        AppManagerAssignment a = new AppManagerAssignment();
        a.setAppId(appId);
        a.setManagerUserId(managerUserId);
        a.setAssignedBy(actorId);
        AppManagerAssignment saved = managerRepo.save(a);
        emitAudit("MANAGER_ASSIGNED", managerUserId, appId, "APP_MANAGER_ASSIGNMENT");
        return saved;
    }

    public void removeManager(String appId, String managerUserId) {
        managerRepo.findByAppIdAndManagerUserId(appId, managerUserId)
                .ifPresent(a -> {
                    managerRepo.delete(a);
                    emitAudit("MANAGER_REMOVED", managerUserId, appId, "APP_MANAGER_ASSIGNMENT");
                });
    }

    public List<AppManagerAssignment> getManagers(String appId) {
        return managerRepo.findByAppId(appId);
    }

    public AppUserAssignment assignUser(String appId, String userId) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String actorId = (String) auth.getPrincipal();
        AppUserAssignment a = new AppUserAssignment();
        a.setAppId(appId);
        a.setUserId(userId);
        a.setAssignedBy(actorId);
        AppUserAssignment saved = userRepo.save(a);
        emitAudit("USER_ASSIGNED", userId, appId, "APP_USER_ASSIGNMENT");
        return saved;
    }

    public void removeUser(String appId, String userId) {
        userRepo.findByAppIdAndUserId(appId, userId)
                .ifPresent(a -> {
                    userRepo.delete(a);
                    emitAudit("USER_REMOVED", userId, appId, "APP_USER_ASSIGNMENT");
                });
    }

    public List<AppUserAssignment> getUsers(String appId) {
        return userRepo.findByAppId(appId);
    }

    private void emitAudit(String eventType, String targetId, String appId, String targetType) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String actorId = auth != null ? (String) auth.getPrincipal() : "system";
        String actorRole = auth != null && !auth.getAuthorities().isEmpty()
                ? auth.getAuthorities().stream().map(GrantedAuthority::getAuthority)
                    .findFirst().orElse("").replace("ROLE_", "") : "";
        auditClient.recordEvent(AuditEventDto.builder()
                .eventType(eventType).actorUserId(actorId).actorRole(actorRole)
                .targetType(targetType).targetId(targetId).appId(appId).build());
    }
}
