package com.example.usermgmt.dto;

import lombok.Data;

@Data
public class CreateUserRequest {
    private String username;
    private String password;
    private String firstName;
    private String lastName;
    private String email;
    private String role;
}
