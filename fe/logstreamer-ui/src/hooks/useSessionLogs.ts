import { useQuery } from "@tanstack/react-query";
import { getSessionLogs } from "../api/logs";

export function useSessionLogs(sessionId?: string) {
  return useQuery({
    queryKey: ["session-logs", sessionId],
    queryFn: () => getSessionLogs(sessionId!),
    enabled: Boolean(sessionId),
    staleTime: 0,
  });
}
