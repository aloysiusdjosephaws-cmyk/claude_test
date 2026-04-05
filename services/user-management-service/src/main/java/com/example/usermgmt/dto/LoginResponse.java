package com.example.usermgmt.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class LoginResponse {
    private String token;
    private String userId;
    private String role;
    private String firstName;
    private String lastName;
}
