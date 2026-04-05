package com.example.appmgmt.service;

import com.example.appmgmt.client.AuditClient;
import com.example.appmgmt.dto.AuditEventDto;
import com.example.appmgmt.dto.CreateApplicationRequest;
import com.example.appmgmt.model.Application;
import com.example.appmgmt.model.AppManagerAssignment;
import com.example.appmgmt.model.AppUserAssignment;
import com.example.appmgmt.repository.AppManagerAssignmentRepository;
import com.example.appmgmt.repository.AppUserAssignmentRepository;
import com.example.appmgmt.repository.ApplicationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ApplicationService {

    private final ApplicationRepository applicationRepository;
    private final AppManagerAssignmentRepository managerRepo;
    private final AppUserAssignmentRepository userRepo;
    private final AuditClient auditClient;

    public List<Application> findAll() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String role = getRole(auth);
        String userId = (String) auth.getPrincipal();

        if ("APP_MANAGER".equals(role)) {
            List<String> appIds = managerRepo.findByManagerUserId(userId)
                    .stream().map(AppManagerAssignment::getAppId).toList();
            return applicationRepository.findByAppIdIn(appIds);
        }
        if ("APP_USER".equals(role)) {
            List<String> appIds = userRepo.findByUserId(userId)
                    .stream().map(AppUserAssignment::getAppId).toList();
            return applicationRepository.findByAppIdIn(appIds);
        }
        return applicationRepository.findAll();
    }

    public Optional<Application> findByAppId(String appId) {
        return applicationRepository.findByAppId(appId);
    }

    public Application create(CreateApplicationRequest req) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String actorId = (String) auth.getPrincipal();
        Application app = new Application();
        app.setAppId("APP-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase());
        app.setAppName(req.getAppName());
        app.setDescription(req.getDescription());
        app.setCreatedBy(actorId);
        Application saved = applicationRepository.save(app);
        emitAudit("APP_CREATED", saved.getAppId(), saved.getAppId());
        return saved;
    }

    public Application update(String appId, CreateApplicationRequest req) {
        Application app = applicationRepository.findByAppId(appId)
                .orElseThrow(() -> new RuntimeException("App not found: " + appId));
        if (req.getAppName() != null) app.setAppName(req.getAppName());
        if (req.getDescription() != null) app.setDescription(req.getDescription());
        Application saved = applicationRepository.save(app);
        emitAudit("APP_UPDATED", saved.getAppId(), saved.getAppId());
        return saved;
    }

    public void delete(String appId) {
        Application app = applicationRepository.findByAppId(appId)
                .orElseThrow(() -> new RuntimeException("App not found: " + appId));
        app.setStatus("INACTIVE");
        applicationRepository.save(app);
        emitAudit("APP_DELETED", appId, appId);
    }

    private void emitAudit(String eventType, String targetId, String appId) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String actorId = auth != null ? (String) auth.getPrincipal() : "system";
        String actorRole = getRole(auth);
        auditClient.recordEvent(AuditEventDto.builder()
                .eventType(eventType).actorUserId(actorId).actorRole(actorRole)
                .targetType("APPLICATION").targetId(targetId).appId(appId).build());
    }

    private String getRole(Authentication auth) {
        if (auth == null || auth.getAuthorities().isEmpty()) return "";
        return auth.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .findFirst().orElse("").replace("ROLE_", "");
    }
}
