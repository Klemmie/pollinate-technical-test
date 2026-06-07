package com.pollinate.technical.configuration;

import io.opentelemetry.api.trace.Span;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.jspecify.annotations.NonNull;
import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import jakarta.servlet.http.HttpServletRequest;

import java.io.IOException;

@Slf4j
@Component
public class CorrelationIdFilter extends OncePerRequestFilter {

    private static final String CORRELATION_ID_HEADER = "X-Correlation-ID";
    private static final String TRACE_ID_MDC_KEY = "correlationId";

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException, ServletException {
        try {
            String correlationId = request.getHeader(CORRELATION_ID_HEADER);

            if (correlationId == null || correlationId.isBlank()){
                correlationId = Span.current().getSpanContext().getTraceId();
            }

            MDC.put(TRACE_ID_MDC_KEY, correlationId);

            response.setHeader(CORRELATION_ID_HEADER, correlationId);

            log.debug("Request received with correlationId: {}", correlationId);

            filterChain.doFilter(request, response);
        } finally {
            MDC.remove(TRACE_ID_MDC_KEY);
        }
    }
}
