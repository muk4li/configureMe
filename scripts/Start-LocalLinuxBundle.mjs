// CM-043 local mode: starts the portal on 127.0.0.1 only with the Linux bundle route enabled.
import { spawn } from "node:child_process";
const next = process.platform === "win32" ? "node_modules\\.bin\\next.cmd" : "node_modules/.bin/next";
const child = spawn(next, ["dev", "--hostname", "127.0.0.1", "--port", process.env.PORT ?? "3000"], {
  stdio: "inherit", shell: process.platform === "win32", env: { ...process.env, CONFIGUREME_LOCAL_LINUX_BUNDLE: "1" },
});
child.on("exit", (code) => process.exit(code ?? 1));
console.log("configureMe lokal: http://127.0.0.1:" + (process.env.PORT ?? "3000") + "/linux");
