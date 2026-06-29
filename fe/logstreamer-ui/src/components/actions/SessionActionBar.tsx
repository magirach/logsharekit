import { useMutation, useQueryClient } from "@tanstack/react-query";
import { resendSessionPush, stopSession } from "../../api/sessions";
import type { Session } from "../../types/session";

export function SessionActionBar({ session }: { session: Session }) {
  const queryClient = useQueryClient();

  const resendMutation = useMutation({
    mutationFn: () => resendSessionPush(session.sessionId),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["session", session.sessionId] });
      void queryClient.invalidateQueries({ queryKey: ["sessions"] });
    },
  });

  const stopMutation = useMutation({
    mutationFn: () => stopSession(session.sessionId),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["session", session.sessionId] });
      void queryClient.invalidateQueries({ queryKey: ["sessions"] });
    },
  });

  return (
    <div className="action-bar">
      <button onClick={() => resendMutation.mutate()} disabled={resendMutation.isPending}>
        {resendMutation.isPending ? "Resending..." : "Resend push"}
      </button>
      <button className="button-danger" onClick={() => stopMutation.mutate()} disabled={stopMutation.isPending}>
        {stopMutation.isPending ? "Stopping..." : "Stop session"}
      </button>
      {resendMutation.error ? <p className="error-copy">{resendMutation.error.message}</p> : null}
      {stopMutation.error ? <p className="error-copy">{stopMutation.error.message}</p> : null}
    </div>
  );
}
