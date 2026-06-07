package com.pollinate.technical.service;

import com.pollinate.technical.dto.ValidationRequest;
import com.pollinate.technical.dto.ValidationResponse;
import com.pollinate.technical.exceptionhandler.ValidationServiceException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.http.HttpStatusCode;
import org.springframework.resilience.annotation.Retryable;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.util.function.Supplier;

@Slf4j
@Service
@RequiredArgsConstructor
public class ValidationService {

    private final WebClient webClient;

    @Retryable(
            maxRetries = 3,
            delay = 10
    )
    public ValidationResponse validate(ValidationRequest validationRequest){
        String correlationId = MDC.get("correlationId");
        log.info("Call RiskShield to determine risk score for {} with correlationId {}", validationRequest.getFirstName(), correlationId);

        try {
            ValidationResponse response = webClient.post()
                    .uri("/v1/score")
                    .header("X-Correlation-ID", correlationId)
                    .bodyValue(validationRequest)
                    .retrieve()
                    .onStatus(
                            HttpStatusCode::is4xxClientError,
                            clientResponse -> {
                                log.error("Authentication failed. {}", clientResponse.statusCode());
                                throw new ValidationServiceException("Client error: " + clientResponse.statusCode());
                            }
                    )
                    .onStatus(
                            HttpStatusCode::is5xxServerError,
                            clientResponse -> {
                                log.error("RiskShield service is currently unavailable. {}", clientResponse.statusCode());
                                throw new ValidationServiceException("RiskShield service is currently unavailable: " + clientResponse.statusCode());
                            }
                    )
                    .bodyToMono(ValidationResponse.class)
                    .block();

            log.info("RiskShield service responded: {}", response);
            return response;
        } catch (ValidationServiceException e) {
            log.error("Validation service exception for user: {} - {}", validationRequest.getFirstName(), e.getMessage());
            throw e;
        } catch (WebClientResponseException e) {
            log.error("Unexpected HTTP error calling validation service, code: {}, message: {}", e.getStatusCode(), e.getMessage());
            throw new ValidationServiceException("Unexpected error from validation service", e);
        } catch (Exception e) {
            log.error("Unexpected error calling validation service for user: {}", validationRequest.getFirstName());
            throw new ValidationServiceException("Failed to call validation service", e);
        }

    }
}
