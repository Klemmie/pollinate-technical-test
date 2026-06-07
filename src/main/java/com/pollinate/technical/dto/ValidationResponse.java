package com.pollinate.technical.dto;

import lombok.Data;

@Data
public class ValidationResponse {
    private final int riskScore = 72;
    private final String riskLevel = "MEDIUM";
}
