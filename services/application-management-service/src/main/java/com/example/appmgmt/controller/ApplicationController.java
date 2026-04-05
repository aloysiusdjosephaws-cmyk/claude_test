package com.example.appmgmt.controller;

import com.example.appmgmt.dto.CreateApplicationRequest;
import com.example.appmgmt.model.Application;
import com.example.appmgmt.service.ApplicationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/applications")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class ApplicationController {

    private final ApplicationService applicationService;

    @GetMapping
    public ResponseEntity<List<Application>> getAll() {
        return ResponseEntity.ok(applicationService.findAll());
    }

    @GetMapping("/{appId}")
    public ResponseEntity<Application> getOne(@PathVariable String appId) {
        return applicationService.findByAppId(appId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<Application> create(@RequestBody CreateApplicationRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(applicationService.create(req));
    }

    @PutMapping("/{appId}")
    public ResponseEntity<Application> update(@PathVariable String appId,
                                              @RequestBody CreateApplicationRequest req) {
        return ResponseEntity.ok(applicationService.update(appId, req));
    }

    @DeleteMapping("/{appId}")
    public ResponseEntity<Void> delete(@PathVariable String appId) {
        applicationService.delete(appId);
        return ResponseEntity.ok().build();
    }
}
