package com.example.docmgmt.repository;

import com.example.docmgmt.model.Document;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface DocumentRepository extends JpaRepository<Document, Long> {

    List<Document> findByAppIdAndDeletedFalse(String appId);

    Optional<Document> findByIdAndDeletedFalse(Long id);

    @Query("SELECT d FROM Document d WHERE d.appId = :appId AND d.deleted = false " +
           "AND d.fileFilter = 'N' " +
           "AND (:keyId IS NULL OR d.keyId = :keyId) " +
           "AND (:docName IS NULL OR LOWER(d.docName) LIKE LOWER(CONCAT('%', :docName, '%'))) " +
           "AND (:groupName IS NULL OR d.groupName = :groupName)")
    List<Document> searchForUser(@Param("appId") String appId,
                                 @Param("keyId") String keyId,
                                 @Param("docName") String docName,
                                 @Param("groupName") String groupName);
}
