import { apiRequest } from "./client";
import type { LogEvent } from "../types/log";

export function getSessionLogs(sessionId: string, limit = 500): Promise<LogEvent[]> {
  return apiRequest<LogEvent[]>(`/api/v1/sessions/${sessionId}/logs?limit=${limit}`);
}
