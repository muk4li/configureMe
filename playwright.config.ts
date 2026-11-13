import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "./tests/browser",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  use: {
    baseURL: "http://127.0.0.1:3100", headless: true,
    launchOptions: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH } : {},
    trace: "retain-on-failure",
  },
  webServer: {
    command: "npm run start -- --hostname 127.0.0.1 --port 3100",
    url: "http://127.0.0.1:3100/api/health", reuseExistingServer: false,
    env: { AUTH_SECRET: "", GITHUB_CLIENT_ID: "", GITHUB_CLIENT_SECRET: "", APP_URL: "http://127.0.0.1:3100", NEXT_TELEMETRY_DISABLED: "1" },
  },
});
