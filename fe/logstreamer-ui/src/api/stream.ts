import { apiBaseUrl } from "./client";

export function streamUrl(sessionId: string): string {
  return `${apiBaseUrl()}/api/v1/sessions/${sessionId}/stream`;
}
