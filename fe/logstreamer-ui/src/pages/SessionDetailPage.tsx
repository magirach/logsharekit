import { useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { SessionActionBar } from "../components/actions/SessionActionBar";
import { ConnectionBadge } from "../components/common/ConnectionBadge";
import { StatusBadge } from "../components/common/StatusBadge";
import { LiveLogViewer } from "../components/logs/LiveLogViewer";
import { SessionMetadataPanel } from "../components/sessions/SessionMetadataPanel";
import { useSessionDetail } from "../hooks/useSessionDetail";
import { useSessionLogs } from "../hooks/useSessionLogs";
import { useSessionStream } from "../hooks/useSessionStream";
import type { LogEvent } from "../types/log";
import type { Session } from "../types/session";

export function SessionDetailPage() {
  const { sessionId } = useParams();
  const sessionQuery = useSessionDetail(sessionId);
  const logsQuery = useSessionLogs(sessionId);
  const queryClient = useQueryClient();
  const [liveLogs, setLiveLogs] = useState<LogEvent[]>([]);

  const baseLogs = logsQuery.data ?? [];

  useEffect(() => {
    setLiveLogs([]);
  }, [sessionId]);

  const mergedLogs = useMemo(() => {
    const seen = new Set<string>();
    return [...baseLogs, ...liveLogs].filter((event) => {
      const key = `${event.eventId}-${event.ingestedAt}`;
      if (seen.has(key)) {
        return false;
      }
      seen.add(key);
      return true;
    });
  }, [baseLogs, liveLogs]);

  const streamState = useSessionStream(sessionId, {
    onLogEvent: (event) => {
      setLiveLogs((current) => [...current, event]);
    },
    onStatusEvent: (session: Session) => {
      queryClient.setQueryData(["session", session.sessionId], session);
      void queryClient.invalidateQueries({ queryKey: ["sessions"] });
    },
  });

  if (!sessionId) {
    return <div className="empty-state">Session ID missing.</div>;
  }

  if (sessionQuery.isLoading) {
    return <div className="empty-state">Loading session...</div>;
  }

  if (sessionQuery.error || !sessionQuery.data) {
    return (
      <div className="empty-state">
        <p>Session not found or backend unavailable.</p>
        <Link to="/">Back to dashboard</Link>
      </div>
    );
  }

  const session = sessionQuery.data;

  return (
    <div className="detail-layout">
      <section className="panel detail-header">
        <div className="detail-header__top">
          <div>
            <Link className="back-link" to="/">← Back to dashboard</Link>
            <h2>{session.sessionId}</h2>
            <p className="hero-copy">
              {session.appId} / {session.environment} / {session.userId}
            </p>
          </div>
          <div className="detail-header__status">
            <StatusBadge status={session.status} />
            <ConnectionBadge state={streamState.connectionState} lastHeartbeatAt={streamState.lastHeartbeatAt} />
          </div>
        </div>
        <SessionActionBar session={session} />
      </section>

      <SessionMetadataPanel session={session} />
      <LiveLogViewer logs={mergedLogs} />
    </div>
  );
}
