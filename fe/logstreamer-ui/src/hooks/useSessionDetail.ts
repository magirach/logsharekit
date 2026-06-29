import { useQuery } from "@tanstack/react-query";
import { getSession } from "../api/sessions";

export function useSessionDetail(sessionId?: string) {
  return useQuery({
    queryKey: ["session", sessionId],
    queryFn: () => getSession(sessionId!),
    enabled: Boolean(sessionId),
    refetchInterval: 20_000,
  });
}
