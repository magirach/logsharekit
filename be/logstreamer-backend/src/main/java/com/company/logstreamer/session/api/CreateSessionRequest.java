package com.company.logstreamer.session.api;

import com.company.logstreamer.session.domain.StopPolicy;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record CreateSessionRequest(
        @NotBlank String appId,
        @NotBlank String environment,
        @NotBlank String bundleIdentifier,
        @NotBlank String apnsToken,
        @NotBlank String userId,
        @NotBlank String logs,
        @NotNull @Valid StopPolicy stopPolicy,
        @NotNull Integer retentionHours,
        String logPath
) {
}
