package com.example.audit.repository;

import com.example.audit.model.AuditEvent;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDateTime;

public interface AuditEventRepository extends JpaRepository<AuditEvent, Long> {

    @Query("SELECT a FROM AuditEvent a WHERE " +
           "(:actorUserId IS NULL OR a.actorUserId = :actorUserId) AND " +
           "(:eventType IS NULL OR a.eventType = :eventType) AND " +
           "(:appId IS NULL OR a.appId = :appId) AND " +
           "(:fromDate IS NULL OR a.occurredAt >= :fromDate) AND " +
           "(:toDate IS NULL OR a.occurredAt <= :toDate) " +
           "ORDER BY a.occurredAt DESC")
    Page<AuditEvent> findWithFilters(
        @Param("actorUserId") String actorUserId,
        @Param("eventType") String eventType,
        @Param("appId") String appId,
        @Param("fromDate") LocalDateTime fromDate,
        @Param("toDate") LocalDateTime toDate,
        Pageable pageable
    );
}
