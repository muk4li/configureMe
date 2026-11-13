// One bounded bucket dedicated to public computation; no spoofable identity keys
// and no eviction by unrelated login/bundle traffic. Each process has its own limit.
export function createPlanRateLimiter() {
  let timestamps: number[] = [];
  return (now = Date.now()): boolean => {
    timestamps = timestamps.filter(timestamp => now - timestamp < 60_000);
    if (timestamps.length >= 60) return true;
    timestamps.push(now);
    return false;
  };
}
export const isPublicPlanRateLimited = createPlanRateLimiter();
