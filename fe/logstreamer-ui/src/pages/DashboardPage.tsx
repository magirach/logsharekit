import { useMemo } from "react";
import { CreateSessionPanel } from "../components/actions/CreateSessionPanel";
import { SessionSearchBar } from "../components/sessions/SessionSearchBar";
import { SessionListSection } from "../components/sessions/SessionListSection";
import { useSessions } from "../hooks/useSessions";

export function DashboardPage() {
  const activeQuery = useSessions(true);
  const recentQuery = useSessions(false);

  const recentSessions = useMemo(() => recentQuery.data ?? [], [recentQuery.data]);
  const activeSessions = useMemo(() => activeQuery.data ?? [], [activeQuery.data]);

  return (
    <div className="dashboard-grid">
      <section className="hero-panel">
        <div>
          <p className="eyebrow">Foreground capture only</p>
          <h2>Run sessions, watch live logs, intervene fast.</h2>
          <p className="hero-copy">
            Internal control surface for iOS remote log streaming. Start a session, monitor consent and activity,
            inspect logs live, and resend or stop without leaving the page.
          </p>
        </div>
        <SessionSearchBar />
      </section>

      <CreateSessionPanel />

      <SessionListSection
        title="Active Sessions"
        description={activeQuery.isLoading ? "Loading active sessions" : "Sessions with live operator attention"}
        sessions={activeSessions}
      />

      <SessionListSection
        title="Recent Sessions"
        description={recentQuery.isLoading ? "Loading recent sessions" : "Retention-window history"}
        sessions={recentSessions}
      />
    </div>
  );
}
