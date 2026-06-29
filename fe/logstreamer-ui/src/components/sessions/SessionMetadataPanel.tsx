import type { Session } from "../../types/session";

export function SessionMetadataPanel({ session }: { session: Session }) {
  const metadataItems = [
    { label: "App", value: session.appId },
    { label: "Environment", value: session.environment },
    { label: "Bundle ID", value: session.bundleIdentifier },
    { label: "User", value: session.userId },
    { label: "Retention hours", value: String(session.retentionHours) },
    { label: "Resend count", value: String(session.resendCount) },
    { label: "Consent", value: session.consentStatus },
    { label: "Created", value: new Date(session.createdAt).toLocaleString() },
    {
      label: "Activity",
      value: session.lastClientActivityAt ? new Date(session.lastClientActivityAt).toLocaleString() : "No activity yet",
    },
    {
      label: "Requested logs",
      value: session.logs.join(", "),
      wide: true,
    },
    {
      label: "Stop policy",
      value: `${session.stopPolicy.expiresAfterMinutes ?? "-"}m / ${session.stopPolicy.maxEvents ?? "-"} events / ${session.stopPolicy.maxBytes ?? "-"} bytes`,
      wide: true,
    },
  ];

  return (
    <section className="panel metadata-panel">
      <div className="panel__header">
        <div>
          <p className="eyebrow">Session context</p>
          <h2>Metadata</h2>
        </div>
      </div>
      <div className="metadata-grid">
        {metadataItems.map((item) => (
          <div key={item.label} className={item.wide ? "metadata-grid__item metadata-grid__item--wide" : "metadata-grid__item"}>
            <span>{item.label}</span>
            <strong title={item.value}>{item.value}</strong>
          </div>
        ))}
      </div>
    </section>
  );
}
