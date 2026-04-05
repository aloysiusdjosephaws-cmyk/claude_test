package com.example.docmgmt.dto;

import lombok.Data;

@Data
public class UpdateDocumentRequest {
    private String description;
    private String groupName;
}
