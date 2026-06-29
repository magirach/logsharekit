export type SessionStatus =
  | "PENDING"
  | "CONSENT_REQUESTED"
  | "ACTIVE"
  | "PAUSED"
  | "COMPLETED"
  | "CANCELLED"
  | "FAILED"
  | "EXPIRED";

export type ConsentStatus = "UNKNOWN" | "SHOWN" | "ACCEPTED" | "DENIED";

export interface StopPolicy {
  expiresAfterMinutes?: number | null;
  maxEvents?: number | null;
  maxBytes?: number | null;
}

export interface Session {
  sessionId: string;
  appId: string;
  environment: string;
  bundleIdentifier: string;
  userId: string;
  logs: string[];
  status: SessionStatus;
  consentStatus: ConsentStatus;
  stopPolicy: StopPolicy;
  retentionHours: number;
  createdAt: string;
  consentShownAt?: string | null;
  activatedAt?: string | null;
  endedAt?: string | null;
  lastClientActivityAt?: string | null;
  resendCount: number;
}

export interface SessionCreateResponse {
  sessionId: string;
  status: SessionStatus;
  createdAt: string;
}

export interface CreateSessionInput {
  appId: string;
  environment: string;
  bundleIdentifier: string;
  apnsToken: string;
  userId: string;
  logs: string;
  stopPolicy: {
    expiryMinutes?: number | null;
    maxEvents?: number | null;
    maxBytes?: number | null;
  };
  retentionHours: number;
}
