import { useEffect, useRef } from "react";

export function useAutoScroll(enabled: boolean, dependency: unknown) {
  const containerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!enabled || !containerRef.current) {
      return;
    }
    const container = containerRef.current;
    container.scrollTop = container.scrollHeight;
  }, [enabled, dependency]);

  return containerRef;
}
