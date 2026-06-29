import { useState } from "react";
import type { LogEvent } from "../../types/log";

export function LogRow({ event }: { event: LogEvent }) {
  const [expanded, setExpanded] = useState(false);
  const payloadString = event.payload ? JSON.stringify(event.payload, null, 2) : "";

  return (
    <article className={`log-row log-level-${(event.level ?? "INFO").toLowerCase()}`}>
      <div className="log-row__header">
        <div>
          <strong>{event.type}</strong>
          <span>{event.component}</span>
          <small>{new Date(event.timestamp).toLocaleString()}</small>
        </div>
        <div className="log-row__level">{event.level ?? "INFO"}</div>
      </div>
      {event.message ? <p className="log-row__message">{event.message}</p> : null}
      {Object.keys(event.metadata).length > 0 ? (
        <div className="meta-pills">
          {Object.entries(event.metadata).map(([key, value]) => (
            <span key={`${key}-${value}`}>{key}: {value}</span>
          ))}
        </div>
      ) : null}
      {payloadString ? (
        <div className="payload-block">
          <button className="payload-toggle" onClick={() => setExpanded((current) => !current)} type="button">
            {expanded ? "Hide payload" : "Show payload"}
          </button>
          {expanded ? <pre>{payloadString}</pre> : null}
        </div>
      ) : null}
    </article>
  );
}
