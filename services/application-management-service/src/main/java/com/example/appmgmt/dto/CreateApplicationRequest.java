package com.example.appmgmt.dto;

import lombok.Data;

@Data
public class CreateApplicationRequest {
    private String appName;
    private String description;
}
