package com.example.audit.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpMethod;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Validates X-Internal-Key header for POST /audit/events.
 * If the key is missing or wrong, returns 401 immediately.
 */
public class InternalKeyFilter extends OncePerRequestFilter {

    private final String expectedKey;

    public InternalKeyFilter(String expectedKey) {
        this.expectedKey = expectedKey;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        if (HttpMethod.POST.name().equalsIgnoreCase(request.getMethod())
                && request.getRequestURI().equals("/audit/events")) {
            String key = request.getHeader("X-Internal-Key");
            if (!expectedKey.equals(key)) {
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.getWriter().write("{\"error\":\"Unauthorized\"}");
                return;
            }
        }
        chain.doFilter(request, response);
    }
}
