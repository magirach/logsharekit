import { useMutation, useQueryClient } from "@tanstack/react-query";
import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { createSession } from "../../api/sessions";
import type { CreateSessionInput } from "../../types/session";

const initialForm: CreateSessionInput = {
  appId: "ios-app",
  environment: "internal",
  bundleIdentifier: "",
  apnsToken: "",
  userId: "",
  logs: "network,crash,logs",
  stopPolicy: {
    expiryMinutes: 30,
    maxEvents: null,
    maxBytes: null,
  },
  retentionHours: 24,
};

export function CreateSessionPanel() {
  const [form, setForm] = useState<CreateSessionInput>(initialForm);
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: createSession,
    onSuccess: (session) => {
      void queryClient.invalidateQueries({ queryKey: ["sessions"] });
      navigate(`/sessions/${session.sessionId}`);
    },
  });

  function submit(event: FormEvent) {
    event.preventDefault();
    mutation.mutate({
      ...form,
      retentionHours: Number(form.retentionHours),
      stopPolicy: {
        expiryMinutes: form.stopPolicy.expiryMinutes ? Number(form.stopPolicy.expiryMinutes) : null,
        maxEvents: form.stopPolicy.maxEvents ? Number(form.stopPolicy.maxEvents) : null,
        maxBytes: form.stopPolicy.maxBytes ? Number(form.stopPolicy.maxBytes) : null,
      },
    });
  }

  return (
    <section className="panel create-session">
      <div className="panel__header">
        <div>
          <p className="eyebrow">Start a new remote capture</p>
          <h2>Create Session</h2>
        </div>
      </div>
      <form className="form-grid" onSubmit={submit}>
        <label>
          <span>App ID</span>
          <input
            value={form.appId}
            onChange={(event) => setForm((current) => ({ ...current, appId: event.target.value }))}
            required
          />
        </label>
        <label>
          <span>Environment</span>
          <input
            value={form.environment}
            onChange={(event) => setForm((current) => ({ ...current, environment: event.target.value }))}
            required
          />
        </label>
        <label className="form-grid__full">
          <span>Bundle identifier</span>
          <input
            value={form.bundleIdentifier}
            onChange={(event) => setForm((current) => ({ ...current, bundleIdentifier: event.target.value }))}
            placeholder="com.example.myapp"
            required
          />
        </label>
        <label className="form-grid__full">
          <span>APNs token</span>
          <textarea
            rows={3}
            value={form.apnsToken}
            onChange={(event) => setForm((current) => ({ ...current, apnsToken: event.target.value }))}
            required
          />
        </label>
        <label>
          <span>User ID</span>
          <input
            value={form.userId}
            onChange={(event) => setForm((current) => ({ ...current, userId: event.target.value }))}
            required
          />
        </label>
        <label>
          <span>Logs CSV</span>
          <input
            value={form.logs}
            onChange={(event) => setForm((current) => ({ ...current, logs: event.target.value }))}
            placeholder="network,crash,logs"
            required
          />
        </label>
        <label>
          <span>Expiry minutes</span>
          <input
            type="number"
            min="1"
            value={form.stopPolicy.expiryMinutes ?? ""}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                stopPolicy: { ...current.stopPolicy, expiryMinutes: Number(event.target.value) || null },
              }))
            }
            required
          />
        </label>
        <label>
          <span>Retention hours</span>
          <input
            type="number"
            min="1"
            value={form.retentionHours}
            onChange={(event) => setForm((current) => ({ ...current, retentionHours: Number(event.target.value) }))}
            required
          />
        </label>
        <label>
          <span>Max events</span>
          <input
            type="number"
            min="0"
            value={form.stopPolicy.maxEvents ?? ""}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                stopPolicy: { ...current.stopPolicy, maxEvents: Number(event.target.value) || null },
              }))
            }
          />
        </label>
        <label>
          <span>Max bytes</span>
          <input
            type="number"
            min="0"
            value={form.stopPolicy.maxBytes ?? ""}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                stopPolicy: { ...current.stopPolicy, maxBytes: Number(event.target.value) || null },
              }))
            }
          />
        </label>
        <div className="form-actions form-grid__full">
          <button type="submit" disabled={mutation.isPending}>
            {mutation.isPending ? "Creating..." : "Create and open"}
          </button>
          {mutation.error ? <p className="error-copy">{mutation.error.message}</p> : null}
        </div>
      </form>
    </section>
  );
}
