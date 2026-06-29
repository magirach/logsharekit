export interface LogEvent {
  eventId: string;
  sessionId: string;
  appId: string;
  timestamp: string;
  ingestedAt: string;
  type: string;
  level?: string | null;
  component: string;
  message?: string | null;
  metadata: Record<string, string>;
  payload?: unknown;
}
