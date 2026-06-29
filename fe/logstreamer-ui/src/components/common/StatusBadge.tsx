import type { SessionStatus } from "../../types/session";

export function StatusBadge({ status }: { status: SessionStatus }) {
  return <span className={`status-badge status-${status.toLowerCase()}`}>{status.replace(/_/g, " ")}</span>;
}
