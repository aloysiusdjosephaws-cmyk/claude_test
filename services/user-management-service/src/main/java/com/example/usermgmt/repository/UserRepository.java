package com.example.usermgmt.repository;

import com.example.usermgmt.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
    Optional<User> findByUserId(String userId);
    List<User> findByRole(String role);
    List<User> findByRoleIn(List<String> roles);
    boolean existsByUsername(String username);
}
