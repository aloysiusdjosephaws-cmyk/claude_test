package com.example.appmgmt.controller;

import com.example.appmgmt.dto.AssignmentRequest;
import com.example.appmgmt.service.AssignmentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/applications")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class AssignmentController {

    private final AssignmentService assignmentService;

    @PostMapping("/{appId}/managers")
    public ResponseEntity<?> assignManager(@PathVariable String appId,
                                           @RequestBody AssignmentRequest req) {
        return ResponseEntity.ok(assignmentService.assignManager(appId, req.getUserId()));
    }

    @DeleteMapping("/{appId}/managers/{userId}")
    public ResponseEntity<Void> removeManager(@PathVariable String appId,
                                              @PathVariable String userId) {
        assignmentService.removeManager(appId, userId);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/{appId}/managers")
    public ResponseEntity<?> getManagers(@PathVariable String appId) {
        return ResponseEntity.ok(assignmentService.getManagers(appId));
    }

    @PostMapping("/{appId}/users")
    public ResponseEntity<?> assignUser(@PathVariable String appId,
                                        @RequestBody AssignmentRequest req) {
        return ResponseEntity.ok(assignmentService.assignUser(appId, req.getUserId()));
    }

    @DeleteMapping("/{appId}/users/{userId}")
    public ResponseEntity<Void> removeUser(@PathVariable String appId,
                                           @PathVariable String userId) {
        assignmentService.removeUser(appId, userId);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/{appId}/users")
    public ResponseEntity<?> getUsers(@PathVariable String appId) {
        return ResponseEntity.ok(assignmentService.getUsers(appId));
    }
}
