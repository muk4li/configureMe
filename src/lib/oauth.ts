export function getPublicBaseUrl(requestOrigin: string): URL | undefined {
  const configuredUrl = process.env.APP_URL;
  if (process.env.NODE_ENV === "production" && !configuredUrl) return undefined;

  try {
    const base = new URL(configuredUrl ?? requestOrigin);
    if (
      (base.protocol !== "https:" && base.protocol !== "http:") ||
      (process.env.NODE_ENV === "production" && base.protocol !== "https:") ||
      base.username ||
      base.password
    ) {
      return undefined;
    }
    return base;
  } catch {
    return undefined;
  }
}

export function getGitHubCallbackUrl(requestOrigin: string): string | undefined {
  const base = getPublicBaseUrl(requestOrigin);
  if (!base) return undefined;

  return new URL("/api/auth/github/callback", base.origin).toString();
}

export function isExpectedRequestOrigin(originHeader: string | null, requestOrigin: string): boolean {
  if (!originHeader) return false;
  const expected = process.env.NODE_ENV === "production"
    ? process.env.APP_URL
    : requestOrigin;
  if (!expected) return false;

  try {
    return new URL(originHeader).origin === new URL(expected).origin;
  } catch {
    return false;
  }
}
