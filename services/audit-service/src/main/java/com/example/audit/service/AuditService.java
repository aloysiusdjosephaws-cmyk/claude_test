package com.example.audit.service;

import com.example.audit.dto.AuditEventDto;
import com.example.audit.model.AuditEvent;
import com.example.audit.repository.AuditEventRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class AuditService {

    private final AuditEventRepository repository;

    public AuditEvent save(AuditEventDto dto) {
        AuditEvent event = new AuditEvent();
        event.setEventType(dto.getEventType());
        event.setActorUserId(dto.getActorUserId());
        event.setActorRole(dto.getActorRole());
        event.setTargetType(dto.getTargetType());
        event.setTargetId(dto.getTargetId());
        event.setAppId(dto.getAppId());
        event.setPayload(dto.getPayload());
        event.setIpAddress(dto.getIpAddress());
        return repository.save(event);
    }

    public Page<AuditEvent> findAll(String actorUserId, String eventType, String appId,
                                    LocalDateTime fromDate, LocalDateTime toDate,
                                    int page, int size) {
        return repository.findWithFilters(actorUserId, eventType, appId, fromDate, toDate,
                PageRequest.of(page, size));
    }

    public Optional<AuditEvent> findById(Long id) {
        return repository.findById(id);
    }
}
