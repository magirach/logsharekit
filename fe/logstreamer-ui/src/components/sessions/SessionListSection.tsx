import type { Session } from "../../types/session";
import { SessionCard } from "./SessionCard";

export function SessionListSection({
  title,
  description,
  sessions,
}: {
  title: string;
  description: string;
  sessions: Session[];
}) {
  return (
    <section className="panel">
      <div className="panel__header">
        <div>
          <p className="eyebrow">{description}</p>
          <h2>{title}</h2>
        </div>
        <span className="panel__count">{sessions.length}</span>
      </div>
      <div className="session-list">
        {sessions.length === 0 ? <div className="empty-state">No sessions to display.</div> : null}
        {sessions.map((session) => (
          <SessionCard key={session.sessionId} session={session} />
        ))}
      </div>
    </section>
  );
}
