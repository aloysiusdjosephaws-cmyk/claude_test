package com.example.usermgmt.controller;

import com.example.usermgmt.dto.CreateUserRequest;
import com.example.usermgmt.dto.UpdateUserRequest;
import com.example.usermgmt.model.User;
import com.example.usermgmt.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class UserController {

    private final UserService userService;

    @GetMapping
    public ResponseEntity<List<User>> getUsers(@RequestParam(required = false) String role,
                                               Authentication auth) {
        String callerRole = getRole(auth);
        if ("PROJECT_OFFICER".equals(callerRole)) {
            // Project officers only see APP_MANAGER and APP_USER
            List<User> users = role != null
                    ? userService.findAll(role)
                    : userService.findByRoles(List.of("APP_MANAGER", "APP_USER"));
            return ResponseEntity.ok(users);
        }
        return ResponseEntity.ok(userService.findAll(role));
    }

    @PostMapping
    public ResponseEntity<?> createUser(@RequestBody CreateUserRequest req, Authentication auth) {
        String callerRole = getRole(auth);
        // ProjectOfficer can only create APP_MANAGER and APP_USER
        if ("PROJECT_OFFICER".equals(callerRole) &&
                !List.of("APP_MANAGER", "APP_USER").contains(req.getRole())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body("{\"error\":\"ProjectOfficer can only create APP_MANAGER or APP_USER\"}");
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(userService.createUser(req));
    }

    @GetMapping("/{userId}")
    public ResponseEntity<User> getUser(@PathVariable String userId) {
        return userService.findByUserId(userId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{userId}")
    public ResponseEntity<User> updateUser(@PathVariable String userId,
                                           @RequestBody UpdateUserRequest req) {
        return ResponseEntity.ok(userService.updateUser(userId, req));
    }

    @DeleteMapping("/{userId}")
    public ResponseEntity<Void> deleteUser(@PathVariable String userId) {
        userService.deleteUser(userId);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/me")
    public ResponseEntity<User> me(Authentication auth) {
        String userId = (String) auth.getPrincipal();
        return userService.findByUserId(userId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    private String getRole(Authentication auth) {
        if (auth == null) return "";
        return auth.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .findFirst()
                .orElse("")
                .replace("ROLE_", "");
    }
}
