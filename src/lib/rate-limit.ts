const requests = new Map<string, number[]>();
const MAX_RATE_LIMIT_KEYS = 5000;

export function isRateLimited(key: string, limit = 10, windowMs = 60_000): boolean {
  const now = Date.now();
  const recent = (requests.get(key) ?? []).filter((timestamp) => now - timestamp < windowMs);
  if (recent.length >= limit) {
    requests.set(key, recent);
    return true;
  }
  if (!requests.has(key) && requests.size >= MAX_RATE_LIMIT_KEYS) {
    for (const [storedKey, timestamps] of requests) {
      if (!timestamps.some((timestamp) => now - timestamp < windowMs)) requests.delete(storedKey);
      if (requests.size < MAX_RATE_LIMIT_KEYS) break;
    }
    if (requests.size >= MAX_RATE_LIMIT_KEYS) {
      const oldest = requests.keys().next().value;
      if (oldest) requests.delete(oldest);
    }
  }
  recent.push(now);
  requests.set(key, recent);
  return false;
}
