package com.example.usermgmt.service;

import com.example.usermgmt.dto.LoginRequest;
import com.example.usermgmt.dto.LoginResponse;
import com.example.usermgmt.model.User;
import com.example.usermgmt.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public LoginResponse login(LoginRequest req) {
        User user = userRepository.findByUsername(req.getUsername())
                .orElseThrow(() -> new RuntimeException("Invalid credentials"));
        if (!"ACTIVE".equals(user.getStatus())) {
            throw new RuntimeException("User account is inactive");
        }
        if (!passwordEncoder.matches(req.getPassword(), user.getPasswordHash())) {
            throw new RuntimeException("Invalid credentials");
        }
        String token = jwtService.generateToken(user);
        return new LoginResponse(token, user.getUserId(), user.getRole(),
                user.getFirstName(), user.getLastName());
    }
}
