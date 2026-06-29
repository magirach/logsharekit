function fallbackBaseUrl(): string {
  if (typeof window === "undefined") {
    return "http://localhost:8080";
  }
  return `${window.location.protocol}//${window.location.hostname}:8080`;
}

export function apiBaseUrl(): string {
  if (import.meta.env.DEV) {
    return "";
  }
  const configured = import.meta.env.VITE_API_BASE_URL as string | undefined;
  return (configured && configured.trim()) || fallbackBaseUrl();
}

function resolveUrl(path: string): string {
  if (path.startsWith("http")) {
    return path;
  }
  return `${apiBaseUrl()}${path}`;
}

export async function apiRequest<T>(
  path: string,
  init?: RequestInit,
): Promise<T> {
  const response = await fetch(resolveUrl(path), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || `Request failed with ${response.status}`);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return (await response.json()) as T;
}

export async function apiRequestVoid(
  path: string,
  init?: RequestInit,
): Promise<void> {
  await apiRequest<unknown>(path, init);
}
