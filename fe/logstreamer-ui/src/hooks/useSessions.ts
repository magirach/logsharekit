import { useQuery } from "@tanstack/react-query";
import { getSessions } from "../api/sessions";

export function useSessions(activeOnly = false) {
  return useQuery({
    queryKey: ["sessions", { activeOnly }],
    queryFn: () => getSessions(activeOnly),
    refetchInterval: activeOnly ? 15_000 : 30_000,
  });
}
