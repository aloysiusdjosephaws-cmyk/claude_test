package com.example.usermgmt.service;

import com.example.usermgmt.client.AuditClient;
import com.example.usermgmt.dto.AuditEventDto;
import com.example.usermgmt.dto.CreateUserRequest;
import com.example.usermgmt.dto.UpdateUserRequest;
import com.example.usermgmt.model.User;
import com.example.usermgmt.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuditClient auditClient;

    public List<User> findAll(String roleFilter) {
        if (roleFilter != null && !roleFilter.isEmpty()) {
            return userRepository.findByRole(roleFilter);
        }
        return userRepository.findAll();
    }

    public List<User> findByRoles(List<String> roles) {
        return userRepository.findByRoleIn(roles);
    }

    public Optional<User> findByUserId(String userId) {
        return userRepository.findByUserId(userId);
    }

    public User createUser(CreateUserRequest req) {
        User user = new User();
        user.setUserId("USR-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase());
        user.setUsername(req.getUsername());
        user.setPasswordHash(passwordEncoder.encode(req.getPassword()));
        user.setFirstName(req.getFirstName());
        user.setLastName(req.getLastName());
        user.setEmail(req.getEmail());
        user.setRole(req.getRole());
        user.setStatus("ACTIVE");
        User saved = userRepository.save(user);
        emitAudit("USER_CREATED", saved.getUserId(), saved.getUserId());
        return saved;
    }

    public User updateUser(String userId, UpdateUserRequest req) {
        User user = userRepository.findByUserId(userId)
                .orElseThrow(() -> new RuntimeException("User not found: " + userId));
        if (req.getFirstName() != null) user.setFirstName(req.getFirstName());
        if (req.getLastName() != null) user.setLastName(req.getLastName());
        if (req.getEmail() != null) user.setEmail(req.getEmail());
        if (req.getStatus() != null) user.setStatus(req.getStatus());
        User saved = userRepository.save(user);
        emitAudit("USER_UPDATED", saved.getUserId(), saved.getUserId());
        return saved;
    }

    public void deleteUser(String userId) {
        User user = userRepository.findByUserId(userId)
                .orElseThrow(() -> new RuntimeException("User not found: " + userId));
        user.setStatus("INACTIVE");
        userRepository.save(user);
        emitAudit("USER_DELETED", userId, userId);
    }

    private void emitAudit(String eventType, String targetId, String targetUserId) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        String actorId = auth != null ? (String) auth.getPrincipal() : "system";
        String actorRole = auth != null && !auth.getAuthorities().isEmpty()
                ? auth.getAuthorities().iterator().next().getAuthority().replace("ROLE_", "")
                : "UNKNOWN";
        auditClient.recordEvent(AuditEventDto.builder()
                .eventType(eventType)
                .actorUserId(actorId)
                .actorRole(actorRole)
                .targetType("USER")
                .targetId(targetId)
                .build());
    }
}
