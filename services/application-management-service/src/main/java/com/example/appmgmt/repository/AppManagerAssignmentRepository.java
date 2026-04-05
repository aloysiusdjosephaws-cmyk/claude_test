package com.example.appmgmt.repository;

import com.example.appmgmt.model.AppManagerAssignment;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface AppManagerAssignmentRepository extends JpaRepository<AppManagerAssignment, Long> {
    List<AppManagerAssignment> findByAppId(String appId);
    List<AppManagerAssignment> findByManagerUserId(String managerUserId);
    Optional<AppManagerAssignment> findByAppIdAndManagerUserId(String appId, String managerUserId);
}
