import { spawn } from "node:child_process";
import { readdir } from "node:fs/promises";
import { createRequire } from "node:module";
import { hasPreviewEnvFiles, previewEnvironment, previewPort } from "./PreviewEnvironment.mjs";
const require = createRequire(import.meta.url);
if (hasPreviewEnvFiles(await readdir(process.cwd())))
  throw new Error("Preview requires a clean checkout without .env files. Use the documented temporary workspace.");
const port = previewPort(process.env.CONFIGUREME_PREVIEW_PORT);
const environment = previewEnvironment(process.env, port);
console.log(`Public fixture preview: http://127.0.0.1:${port} · no OAuth, installers or executable downloads.`);
const child = spawn(process.execPath, [require.resolve("next/dist/bin/next"), "dev", "--hostname", "127.0.0.1", "--port", port], { stdio: "inherit", env: environment });
child.on("error", error => { console.error(error.message); process.exitCode = 1; });
child.on("exit", code => { process.exitCode = code ?? 1; });
