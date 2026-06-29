import { Link } from "react-router-dom";
import type { Session } from "../../types/session";
import { StatusBadge } from "../common/StatusBadge";

export function SessionCard({ session }: { session: Session }) {
  return (
    <Link className="session-card" to={`/sessions/${session.sessionId}`}>
      <div className="session-card__row">
        <strong>{session.sessionId}</strong>
        <StatusBadge status={session.status} />
      </div>
      <div className="session-card__meta">
        <span>{session.appId}</span>
        <span>{session.environment}</span>
        <span>{session.userId}</span>
      </div>
      <div className="session-card__logs">
        {session.logs.map((item) => (
          <span key={item}>{item}</span>
        ))}
      </div>
      <small>Updated {new Date(session.lastClientActivityAt ?? session.createdAt).toLocaleString()}</small>
    </Link>
  );
}
