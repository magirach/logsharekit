import { apiRequest, apiRequestVoid } from "./client";
import type { CreateSessionInput, Session, SessionCreateResponse } from "../types/session";

export function getSessions(activeOnly = false): Promise<Session[]> {
  return apiRequest<Session[]>(`/api/v1/sessions?activeOnly=${activeOnly}`);
}

export function getSession(sessionId: string): Promise<Session> {
  return apiRequest<Session>(`/api/v1/sessions/${sessionId}`);
}

export function createSession(input: CreateSessionInput): Promise<SessionCreateResponse> {
  return apiRequest<SessionCreateResponse>("/api/v1/sessions", {
    method: "POST",
    body: JSON.stringify(input),
  });
}

export function resendSessionPush(sessionId: string): Promise<Session> {
  return apiRequest<Session>(`/api/v1/sessions/${sessionId}/resend`, {
    method: "POST",
  });
}

export function stopSession(sessionId: string): Promise<Session> {
  return apiRequest<Session>(`/api/v1/sessions/${sessionId}/stop`, {
    method: "POST",
  });
}

export interface HealthResponse {
  status: string;
}

export function getHealth(): Promise<HealthResponse> {
  return apiRequest<HealthResponse>("/actuator/health");
}
