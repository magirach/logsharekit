package com.company.logstreamer.ingest.api;

import java.time.Instant;

public record ConsentShownRequest(Instant shownAt) {
}
