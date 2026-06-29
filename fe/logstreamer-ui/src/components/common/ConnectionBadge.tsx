import type { ConnectionState } from "../../types/stream";

export function ConnectionBadge({
  state,
  lastHeartbeatAt,
}: {
  state: ConnectionState;
  lastHeartbeatAt?: string;
}) {
  return (
    <div className={`connection-badge connection-${state}`}>
      <span>{state}</span>
      {lastHeartbeatAt ? <small>heartbeat {new Date(lastHeartbeatAt).toLocaleTimeString()}</small> : null}
    </div>
  );
}
