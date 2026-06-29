import type { LogEvent } from "./log";
import type { Session } from "./session";

export type ConnectionState =
  | "connecting"
  | "connected"
  | "reconnecting"
  | "disconnected"
  | "error";

export interface HeartbeatEvent {
  sessionId: string;
}

export interface SessionStreamState {
  connectionState: ConnectionState;
  lastHeartbeatAt?: string;
}

export interface SessionStreamHandlers {
  onLogEvent: (event: LogEvent) => void;
  onStatusEvent: (session: Session) => void;
}
