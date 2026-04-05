package com.example.appmgmt.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AuditEventDto {
    private String eventType;
    private String actorUserId;
    private String actorRole;
    private String targetType;
    private String targetId;
    private String appId;
    private String payload;
    private String ipAddress;
}
