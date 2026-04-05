package com.example.appmgmt.repository;

import com.example.appmgmt.model.Application;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface ApplicationRepository extends JpaRepository<Application, Long> {
    Optional<Application> findByAppId(String appId);

    @Query("SELECT a FROM Application a WHERE a.appId IN :appIds")
    List<Application> findByAppIdIn(@Param("appIds") List<String> appIds);
}
