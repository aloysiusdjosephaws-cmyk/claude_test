package com.example.docmgmt.controller;

import com.example.docmgmt.model.DocumentGroup;
import com.example.docmgmt.service.DocumentGroupService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/groups")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class GroupController {

    private final DocumentGroupService groupService;

    @GetMapping
    public ResponseEntity<List<DocumentGroup>> list(@RequestParam String appId) {
        return ResponseEntity.ok(groupService.findByAppId(appId));
    }

    @PostMapping
    public ResponseEntity<DocumentGroup> create(@RequestBody Map<String, String> body) {
        return ResponseEntity.ok(groupService.create(body.get("appId"), body.get("groupName")));
    }

    @PutMapping("/{id}")
    public ResponseEntity<DocumentGroup> update(@PathVariable Long id,
                                                @RequestBody Map<String, String> body) {
        return ResponseEntity.ok(groupService.update(id, body.get("groupName")));
    }
}
