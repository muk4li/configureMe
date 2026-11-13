import { spawn } from "node:child_process";
import { readdir } from "node:fs/promises";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
if ((await readdir(process.cwd())).some(name => (name === ".env" || name.startsWith(".env.")) && name !== ".env.example"))
  throw new Error("Preview requires a clean checkout without .env files. Use the documented temporary workspace.");
const previewPort = process.env.CONFIGUREME_PREVIEW_PORT ?? "3000";
if (!/^\d{4,5}$/.test(previewPort) || Number(previewPort) < 1024 || Number(previewPort) > 65535) throw new Error("Choose a preview port between 1024 and 65535.");
const environment = { ...process.env, NEXT_TELEMETRY_DISABLED: "1", APP_URL: `http://127.0.0.1:${previewPort}` };
for (const name of ["AUTH_SECRET", "GITHUB_CLIENT_ID", "GITHUB_CLIENT_SECRET", "INITIAL_ADMIN_GITHUB_USER", "ALLOWED_GITHUB_USERS"])
  delete environment[name];
console.log(`Public fixture preview: http://127.0.0.1:${previewPort} · no OAuth, installers or executable downloads.`);
const child = spawn(process.execPath, [require.resolve("next/dist/bin/next"), "dev", "--hostname", "127.0.0.1", "--port", previewPort], { stdio: "inherit", env: environment });
child.on("error", error => { console.error(error.message); process.exitCode = 1; });
child.on("exit", code => { process.exitCode = code ?? 1; });
