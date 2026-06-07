package com.pollinate.technical.controller;

import com.pollinate.technical.dto.ValidationRequest;
import com.pollinate.technical.dto.ValidationResponse;
import com.pollinate.technical.service.ValidationService;
import io.opentelemetry.api.trace.Span;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequiredArgsConstructor
public class ValidationController {

    private final ValidationService validationService;

    @PostMapping("/validate")
    public ResponseEntity<ValidationResponse> validate(@RequestBody ValidationRequest request){
        String correlationId = Span.current().getSpanContext().getTraceId();
        log.info("Validating risk score for {}", request.getFirstName());

        ValidationResponse response = validationService.validate(request);

        return ResponseEntity.ok(response);
    }
}