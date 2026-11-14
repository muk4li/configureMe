// Synthetic policy fixtures only; never bind these addresses or modify networking.
import { describe, expect, it } from 'vitest';
import { lanConfiguration, lanEnvironment, lanRequestAllowed } from '../scripts/LanPolicy.mjs';
const options = { bind: '192.168.55.10', clients: '192.168.55.11', port: '3200' };
const interfaces = { fixture: [{ address: options.bind, internal: false }] };
const config = lanConfiguration(options, interfaces);
const request = (overrides = {}) => ({ method: 'GET', url: '/linux', socket: { remoteAddress: '192.168.55.11' }, headers: { host: config.host }, ...overrides });
describe('explicit LAN planning policy', () => {
  it.each(['0.0.0.0', '127.0.0.1', '8.8.8.8', '::', '192.168.55.99'])('refuses unsafe or unassigned binding %s', bind => {
    expect(() => lanConfiguration({ ...options, bind }, interfaces)).toThrow();
  });
  it.each(['', '8.8.8.8', '192.168.55.11,192.168.55.11'])('refuses invalid client list %s', clients => {
    expect(() => lanConfiguration({ ...options, clients }, interfaces)).toThrow();
  });
  it('requires supplied port and actual noninternal interface', () => {
    expect(() => lanConfiguration({ ...options, port: '80' }, interfaces)).toThrow();
    expect(() => lanConfiguration(options, { fixture: [{ address: options.bind, internal: true }] })).toThrow();
  });
  it('allows exact client and mapped peer for planning only', () => {
    expect(lanRequestAllowed(config, request())).toBe(true);
    expect(lanRequestAllowed(config, request({ socket: { remoteAddress: '::ffff:192.168.55.11' } }))).toBe(true);
    expect(lanRequestAllowed(config, request({ method: 'POST', url: '/api/public/linux-plan', headers: { host: config.host, origin: config.origin } }))).toBe(true);
  });
  it.each(['/api/linux/bundle', '/api/auth/github', '/api/bootstrap', '/api/profiles', '/dashboard', '/api/public/plan', '//linux', '/%6cinux', '/_next/static/../../api/auth/github', '/_next/static/%2e%2e/api', '/_next/static/../secret', '/_next/static/a\\b'])('blocks protected and nonallowlisted path %s', url => {
    expect(lanRequestAllowed(config, request({ url }))).toBe(false);
  });
  it('rejects peer, host, origin, forwarding and cross-site spoofing', () => {
    expect(lanRequestAllowed(config, request({ socket: { remoteAddress: '192.168.55.99' } }))).toBe(false);
    for (const extra of [{ host: 'evil.example' }, { origin: 'http://evil.example' }, { forwarded: 'for=192.168.55.11' }, { 'x-forwarded-for': '192.168.55.11' }, { 'sec-fetch-site': 'cross-site' }])
      expect(lanRequestAllowed(config, request({ headers: { host: config.host, ...extra } }))).toBe(false);
    expect(lanRequestAllowed(config, request({ method: 'POST', url: '/linux' }))).toBe(false);
  });
  it('strips inherited credentials, disables download and preserves minimal Windows execution env', () => {
    expect(lanEnvironment({ Path: 'fixture', SystemRoot: 'fixture', AUTH_SECRET: 'fixture', github_client_secret: 'fixture', CUSTOM_SECRET: 'fixture', CONFIGUREME_LOCAL_LINUX_DOWNLOADS: '1' }, config)).toEqual({ Path: 'fixture', SystemRoot: 'fixture', APP_URL: config.origin, NEXT_TELEMETRY_DISABLED: '1', CONFIGUREME_LOCAL_LINUX_DOWNLOADS: '0', NODE_ENV: 'development' });
  });
});
