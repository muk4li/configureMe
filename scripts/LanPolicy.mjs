import { isIP } from "node:net";
import { previewEnvironment, previewPort } from "./PreviewEnvironment.mjs";
export function privateIPv4(ip) {
  if (isIP(ip) !== 4) return false;
  const [a, b] = ip.split('.').map(Number);
  return a === 10 || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168);
}
export function lanConfiguration({ bind, clients, port }, interfaces) {
  if (!privateIPv4(bind) || !Object.values(interfaces).flat().some(item => item && !item.internal && item.address === bind))
    throw new Error("Bind must be an explicitly supplied, assigned private IPv4 address.");
  const peers = clients?.split(',') ?? [];
  if (!peers.length || peers.length > 8 || peers.some(ip => !privateIPv4(ip)) || new Set(peers).size !== peers.length)
    throw new Error("Supply one to eight exact private IPv4 client addresses.");
  if (typeof port !== "string") throw new Error("Supply an explicit port.");
  const validatedPort = previewPort(port);
  return Object.freeze({ bind, peers: Object.freeze([...peers, bind]), port: Number(validatedPort), origin: `http://${bind}:${validatedPort}`, host: `${bind}:${validatedPort}` });
}
export function lanRequestAllowed(config, request) {
  const peer = request.socket.remoteAddress?.replace(/^::ffff:/, '');
  if (!config.peers.includes(peer) || request.headers.host !== config.host) return false;
  if (Object.keys(request.headers).some(key => key.toLowerCase() === 'forwarded' || key.toLowerCase().startsWith('x-forwarded-'))) return false;
  if (request.headers.origin && request.headers.origin !== config.origin) return false;
  if (request.headers['sec-fetch-site'] === 'cross-site') return false;
  const pathname = request.url?.split('?')[0];
  if (!pathname || /[%\\]/.test(pathname) || pathname.includes('//') || pathname.split('/').some(segment => segment === '.' || segment === '..')) return false;
  if (request.method === 'POST') return pathname === '/api/public/linux-plan';
  if (!['GET', 'HEAD'].includes(request.method)) return false;
  return pathname === '/' || pathname === '/linux' || pathname === '/icon.svg' || /^\/_next\/(static)\//.test(pathname ?? '');
}
export function lanEnvironment(inherited, config) {
  const env = previewEnvironment(inherited, String(config.port));
  // Only a minimal execution environment is inherited. No portal/provider credentials.
  const allowed = new Set(['PATH', 'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'PATHEXT', 'TEMP', 'TMP', 'HOME', 'USERPROFILE', 'LOCALAPPDATA']);
  const result = {};
  for (const [key, value] of Object.entries(env)) if (allowed.has(key.toUpperCase())) result[key] = value;
  return { ...result, APP_URL: config.origin, NEXT_TELEMETRY_DISABLED: '1', CONFIGUREME_LOCAL_LINUX_DOWNLOADS: '0', NODE_ENV: 'development' };
}
