import { networkInterfaces } from 'node:os';
import { readdir } from 'node:fs/promises';
import { createServer } from 'node:http';
import { parseArgs } from 'node:util';
import { hasPreviewEnvFiles } from './PreviewEnvironment.mjs';
import { lanConfiguration, lanEnvironment, lanRequestAllowed } from './LanPolicy.mjs';

const { values } = parseArgs({ options: { bind: { type: 'string' }, clients: { type: 'string' }, port: { type: 'string' }, start: { type: 'boolean', default: false } }, allowPositionals: false });
const config = lanConfiguration(values, networkInterfaces());
if (hasPreviewEnvFiles(await readdir(process.cwd()))) throw new Error('LAN preview requires a dedicated checkout without .env files.');
console.log(`Planning-only LAN preview: ${config.origin}. Exact client ACL configured. No auth or executable downloads.`);
if (!values.start) {
  console.log('Configuration validated; no listener started. --start requires separate operator/network approval.');
} else {
  const environment = lanEnvironment(process.env, config);
  // Clear inherited provider secrets before importing Next or loading app modules.
  for (const name of Object.keys(process.env)) delete process.env[name];
  Object.assign(process.env, environment);
  const next = (await import('next')).default;
  const app = next({ dev: true, hostname: config.bind, port: config.port });
  await app.prepare();
  const handler = app.getRequestHandler();
  const server = createServer((request, response) => {
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    if (!lanRequestAllowed(config, request)) { response.writeHead(403); response.end('LAN preview request refused.'); return; }
    if (request.url === '/') { response.writeHead(302, { Location: '/linux' }); response.end(); return; }
    Promise.resolve(handler(request, response)).catch(() => { response.destroy(); });
  });
  // No WebSocket/HMR upgrade path or proxy headers bypass the request ACL.
  server.on('upgrade', (_request, socket) => socket.destroy());
  server.headersTimeout = 10000;
  server.requestTimeout = 15000;
  server.on('error', () => { console.error('LAN preview listener failed.'); process.exitCode = 1; server.close(); });
  server.listen(config.port, config.bind);
}
