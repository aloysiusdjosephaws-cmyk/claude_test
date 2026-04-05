package com.example.appmgmt.repository;

import com.example.appmgmt.model.AppUserAssignment;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface AppUserAssignmentRepository extends JpaRepository<AppUserAssignment, Long> {
    List<AppUserAssignment> findByAppId(String appId);
    List<AppUserAssignment> findByUserId(String userId);
    Optional<AppUserAssignment> findByAppIdAndUserId(String appId, String userId);
}
