import { useQuery } from "@tanstack/react-query";
import { getHealth } from "../../api/sessions";

export function HealthBadge() {
  const healthQuery = useQuery({
    queryKey: ["health"],
    queryFn: getHealth,
    refetchInterval: 20_000,
  });

  const healthy = healthQuery.data?.status?.toUpperCase() === "UP";
  const label = healthQuery.isLoading ? "Checking backend" : healthy ? "Backend healthy" : "Backend unavailable";

  return <div className={`health-badge ${healthy ? "is-healthy" : "is-warning"}`}>{label}</div>;
}
