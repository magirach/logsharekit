package com.company.logstreamer.session.domain;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

public final class RequestedLogTypes {
    private static final Set<String> ALLOWED_VALUES = Set.of("network", "crash", "logs");

    private RequestedLogTypes() {
    }

    public static List<String> normalize(String csv) {
        if (csv == null || csv.isBlank()) {
            throw new IllegalArgumentException("logs must contain at least one value");
        }

        LinkedHashSet<String> normalized = new LinkedHashSet<>();
        for (String rawValue : csv.split(",")) {
            String value = rawValue.trim().toLowerCase(Locale.ROOT);
            if (value.isEmpty()) {
                continue;
            }
            if (!ALLOWED_VALUES.contains(value)) {
                throw new IllegalArgumentException("Unsupported log type: " + value + ". Allowed values: network, crash, logs");
            }
            normalized.add(value);
        }

        if (normalized.isEmpty()) {
            throw new IllegalArgumentException("logs must contain at least one value");
        }

        return List.copyOf(normalized);
    }
}
