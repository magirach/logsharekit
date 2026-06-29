import { useEffect, useMemo, useState } from "react";
import type { LogEvent } from "../../types/log";
import { useAutoScroll } from "../../hooks/useAutoScroll";
import { LogRow } from "./LogRow";

export function LiveLogViewer({ logs }: { logs: LogEvent[] }) {
  const [query, setQuery] = useState("");
  const [autoScroll, setAutoScroll] = useState(true);
  const [paused, setPaused] = useState(false);
  const [frozenLogs, setFrozenLogs] = useState<LogEvent[]>([]);

  useEffect(() => {
    if (!paused) {
      setFrozenLogs([]);
    }
  }, [paused]);

  const sourceLogs = paused ? frozenLogs : logs;

  const visibleLogs = useMemo(() => {
    const lower = query.trim().toLowerCase();
    if (!lower) {
      return sourceLogs;
    }
    return sourceLogs.filter((event) => {
      const haystack = [
        event.type,
        event.level ?? "",
        event.component,
        event.message ?? "",
        JSON.stringify(event.metadata),
        JSON.stringify(event.payload ?? null),
      ]
        .join(" ")
        .toLowerCase();
      return haystack.includes(lower);
    });
  }, [sourceLogs, query]);

  const containerRef = useAutoScroll(autoScroll && !paused, visibleLogs.length);

  const handlePausedChange = () => {
    setPaused((current) => {
      if (current) {
        return false;
      }
      setFrozenLogs(logs);
      return true;
    });
  };

  const pausedCount = Math.max(logs.length - frozenLogs.length, 0);

  return (
    <section className="panel log-panel">
      <div className="panel__header">
        <div>
          <p className="eyebrow">Live investigator</p>
          <h2>Log Viewer</h2>
        </div>
        <div className="log-controls">
          <input
            className="log-controls__search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search logs, payloads, metadata"
          />
          <label className="log-toggle">
            <input checked={autoScroll} onChange={() => setAutoScroll((current) => !current)} type="checkbox" />
            Auto-scroll
          </label>
          <label className={`log-toggle ${paused ? "log-toggle--active" : ""}`}>
            <input checked={paused} onChange={handlePausedChange} type="checkbox" />
            Pause render
            {pausedCount > 0 ? <span className="log-toggle__count">+{pausedCount}</span> : null}
          </label>
        </div>
      </div>
      <div className="log-surface" ref={containerRef}>
        {visibleLogs.length === 0 ? <div className="empty-state">No logs yet for this session.</div> : null}
        {visibleLogs.map((event) => (
          <LogRow key={`${event.eventId}-${event.ingestedAt}`} event={event} />
        ))}
      </div>
    </section>
  );
}
