package com.example.fileservice.repository;

import com.example.fileservice.model.FileEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;

public interface FileRepository extends JpaRepository<FileEntity, Long> {

    @Query("SELECT f.id, f.filename, f.contentType FROM FileEntity f")
    List<Object[]> findAllMetadata();
}
