package com.example.fileservice.service;

import com.example.fileservice.model.FileEntity;
import com.example.fileservice.repository.FileRepository;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.LinkedHashMap;
import java.util.stream.Collectors;

@Service
public class FileService {

    private final FileRepository repository;

    public FileService(FileRepository repository) {
        this.repository = repository;
    }

    public FileEntity store(MultipartFile file) throws IOException {
        FileEntity entity = new FileEntity(
                file.getOriginalFilename(),
                file.getContentType(),
                file.getBytes()
        );
        return repository.save(entity);
    }

    public FileEntity load(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new RuntimeException("File not found: " + id));
    }

    public List<Map<String, Object>> listMetadata() {
        return repository.findAllMetadata().stream().map(row -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", row[0]);
            m.put("filename", row[1]);
            m.put("contentType", row[2]);
            return m;
        }).collect(Collectors.toList());
    }
}
