import { describe, expect, it } from "vitest";
import { hasPreviewEnvFiles, previewEnvironment, previewPort } from "../scripts/PreviewEnvironment.mjs";
describe("credential-free loopback preview", () => {
  it("refuses env files regardless of Windows filename casing", () => {
    for (const name of [".env", ".env.local", ".ENV.LOCAL", ".Env.Development"]) expect(hasPreviewEnvFiles([name])).toBe(true);
    expect(hasPreviewEnvFiles(["README.md", ".env.example"])).toBe(false);
  });
  it("strips auth variables case-insensitively without changing the inherited environment", () => {
    const inherited = { AUTH_SECRET: "synthetic", github_client_secret: "synthetic", Github_Client_Id: "synthetic", initial_admin_github_user: "synthetic", ALLOWED_GITHUB_USERS: "synthetic", app_url: "https://synthetic.invalid", next_telemetry_disabled: "0", PATH: "synthetic-tool-path" };
    const result = previewEnvironment(inherited, "3200");
    expect(result).toEqual({ PATH: "synthetic-tool-path", NEXT_TELEMETRY_DISABLED: "1", APP_URL: "http://127.0.0.1:3200" });
    expect(inherited.AUTH_SECRET).toBe("synthetic");
  });
  it("rejects privileged or invalid ports without spawning a process", () => {
    for (const port of ["0000", "0999", "1023", "65536", "3000 --hostname 0.0.0.0"]) expect(() => previewPort(port)).toThrow();
    expect(previewPort()).toBe("3000"); expect(previewPort("3200")).toBe("3200");
  });
});
