package com.pollinate.technical.configuration;

import lombok.Getter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.web.reactive.function.client.WebClient;

@Getter
@Configuration
public class AppConfig {
    @Value("${validation.service.url}")
    private String validationServiceUrl;

    @Value("${validation.service.api-key}")
    private String validationApiKey;

    @Bean
    public WebClient webClient(){
        return WebClient.builder()
                .baseUrl(validationServiceUrl)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .defaultHeader("x-api-key", validationApiKey)
                .build();
    }
}
