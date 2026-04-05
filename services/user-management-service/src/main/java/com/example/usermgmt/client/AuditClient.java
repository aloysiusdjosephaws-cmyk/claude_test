package com.example.usermgmt.client;

import com.example.usermgmt.dto.AuditEventDto;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

@Component
@RequiredArgsConstructor
@Slf4j
public class AuditClient {

    private final RestTemplate restTemplate;

    @Value("${audit.service.url}")
    private String auditServiceUrl;

    @Value("${internal.api.key}")
    private String internalApiKey;

    public void recordEvent(AuditEventDto dto) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.set("X-Internal-Key", internalApiKey);
            headers.set("Content-Type", "application/json");
            restTemplate.postForObject(auditServiceUrl + "/audit/events",
                    new HttpEntity<>(dto, headers), Object.class);
        } catch (Exception e) {
            log.warn("Failed to record audit event: {}", e.getMessage());
        }
    }
}
