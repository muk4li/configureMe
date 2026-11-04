import { createHmac, timingSafeEqual } from "node:crypto";
import { cookies } from "next/headers";

const SESSION_COOKIE = "configureme_session";
const SESSION_MAX_AGE_SECONDS = 60 * 60 * 8;

export type Session = {
  username: string;
  role: "admin" | "user";
  expiresAt: number;
};

function authSecret(): string {
  const secret = process.env.AUTH_SECRET;
  if (!secret || secret.length < 32) throw new Error("AUTH_SECRET must contain at least 32 characters.");
  return secret;
}

function sign(payload: string): string {
  return createHmac("sha256", authSecret()).update(payload).digest("base64url");
}

export function createSessionToken(username: string, role: Session["role"]): string {
  const payload = Buffer.from(
    JSON.stringify({ username, role, expiresAt: Date.now() + SESSION_MAX_AGE_SECONDS * 1000 }),
  ).toString("base64url");
  return `${payload}.${sign(payload)}`;
}

export function verifySessionToken(token: string): Session | undefined {
  const [payload, signature, extra] = token.split(".");
  if (!payload || !signature || extra) return undefined;

  let expected: Buffer;
  let received: Buffer;
  try {
    expected = Buffer.from(sign(payload), "base64url");
    received = Buffer.from(signature, "base64url");
  } catch {
    return undefined;
  }
  if (expected.length !== received.length || !timingSafeEqual(expected, received)) return undefined;

  try {
    const session = JSON.parse(Buffer.from(payload, "base64url").toString("utf8")) as Session;
    if (
      typeof session.username !== "string" ||
      !/^[a-zA-Z0-9-]{1,39}$/.test(session.username) ||
      (session.role !== "admin" && session.role !== "user") ||
      typeof session.expiresAt !== "number" ||
      session.expiresAt <= Date.now()
    ) {
      return undefined;
    }
    return session;
  } catch {
    return undefined;
  }
}

export async function getSession(): Promise<Session | undefined> {
  const token = (await cookies()).get(SESSION_COOKIE)?.value;
  if (!token) return undefined;
  try {
    return verifySessionToken(token);
  } catch {
    return undefined;
  }
}

export function sessionCookieOptions() {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax" as const,
    path: "/",
    maxAge: SESSION_MAX_AGE_SECONDS,
  };
}

export function sessionCookieName() {
  return SESSION_COOKIE;
}

export function isAllowedUser(username: string): boolean {
  const allowed = new Set(
    [process.env.INITIAL_ADMIN_GITHUB_USER, ...(process.env.ALLOWED_GITHUB_USERS ?? "").split(",")]
      .map((value) => value?.trim().toLowerCase())
      .filter((value): value is string => Boolean(value)),
  );
  return allowed.has(username.toLowerCase());
}

export function isInitialAdmin(username: string): boolean {
  return username.toLowerCase() === process.env.INITIAL_ADMIN_GITHUB_USER?.trim().toLowerCase();
}
