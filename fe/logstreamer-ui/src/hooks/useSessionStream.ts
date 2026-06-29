import { useEffect, useRef, useState } from "react";
import type { LogEvent } from "../types/log";
import type { Session } from "../types/session";
import type { SessionStreamHandlers, SessionStreamState } from "../types/stream";
import { streamUrl } from "../api/stream";

export function useSessionStream(
  sessionId: string | undefined,
  handlers: SessionStreamHandlers,
): SessionStreamState {
  const [connectionState, setConnectionState] = useState<SessionStreamState["connectionState"]>("disconnected");
  const [lastHeartbeatAt, setLastHeartbeatAt] = useState<string | undefined>();
  const retryDelayRef = useRef(2_000);
  const handlersRef = useRef(handlers);

  useEffect(() => {
    handlersRef.current = handlers;
  }, [handlers]);

  useEffect(() => {
    if (!sessionId) {
      setConnectionState("disconnected");
      return;
    }

    let eventSource: EventSource | null = null;
    let cancelled = false;
    let retryTimer: number | undefined;

    const connect = () => {
      setConnectionState((current) => (current === "disconnected" ? "connecting" : "reconnecting"));
      eventSource = new EventSource(streamUrl(sessionId));

      eventSource.onopen = () => {
        retryDelayRef.current = 2_000;
        setConnectionState("connected");
      };

      eventSource.addEventListener("session_status", (event) => {
        handlersRef.current.onStatusEvent(JSON.parse((event as MessageEvent).data) as Session);
      });

      eventSource.addEventListener("log_event", (event) => {
        handlersRef.current.onLogEvent(JSON.parse((event as MessageEvent).data) as LogEvent);
      });

      eventSource.addEventListener("heartbeat", () => {
        setLastHeartbeatAt(new Date().toISOString());
      });

      eventSource.onerror = () => {
        eventSource?.close();
        if (cancelled) {
          return;
        }
        setConnectionState("error");
        retryTimer = window.setTimeout(() => {
          retryDelayRef.current = Math.min(retryDelayRef.current * 1.5, 10_000);
          connect();
        }, retryDelayRef.current);
      };
    };

    connect();

    return () => {
      cancelled = true;
      if (retryTimer) {
        window.clearTimeout(retryTimer);
      }
      eventSource?.close();
      setConnectionState("disconnected");
    };
  }, [sessionId]);

  return {
    connectionState,
    lastHeartbeatAt,
  };
}
