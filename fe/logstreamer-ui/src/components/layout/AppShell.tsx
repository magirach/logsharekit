import { Outlet } from "react-router-dom";
import { HealthBadge } from "../common/HealthBadge";

export function AppShell() {
  return (
    <div className="app-shell">
      <div className="app-shell__ambient app-shell__ambient--left" />
      <div className="app-shell__ambient app-shell__ambient--right" />
      <header className="topbar">
        <div>
          <p className="eyebrow">Internal Operations</p>
          <h1>LogStreamer Control Room</h1>
        </div>
        <HealthBadge />
      </header>
      <main className="app-main">
        <Outlet />
      </main>
    </div>
  );
}
