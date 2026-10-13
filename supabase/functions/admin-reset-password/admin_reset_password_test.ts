import { assertEquals, assertMatch, assertNotEquals } from '@std/assert';

import { createHandler, type ResetDeps, temporaryPassword } from './handler.ts';

const ADMIN_ORIGIN = 'http://localhost:3000';
const ADMIN = '10000000-0000-0000-0000-000000000001';
const PROFILE = '10000000-0000-0000-0000-000000000004';

type Call =
  | { step: 'setPassword'; profileId: string; password: string }
  | { step: 'revokeSessions'; authorization: string; profileId: string }
  | { step: 'recordAction'; actorId: string; action: string; targetId: string; details: Record<string, unknown> };

function setup(
  overrides: Partial<Omit<ResetDeps, 'accounts'>> & {
    roles?: Record<string, string>;
    admin?: boolean;
    accounts?: Partial<ResetDeps['accounts']>;
  } = {},
) {
  const calls: Call[] = [];
  const handler = createHandler({
    allowedOrigins: [ADMIN_ORIGIN],
    adminId: () => Promise.resolve((overrides.admin ?? true) ? ADMIN : null),
    generatePassword: () => 'Temp-Pass-123',
    ...overrides,
    accounts: {
      roleOf: (id) => Promise.resolve((overrides.roles ?? { [PROFILE]: 'customer' })[id] ?? null),
      setPassword: (profileId, password) => {
        calls.push({ step: 'setPassword', profileId, password });
        return Promise.resolve();
      },
      revokeSessions: (authorization, profileId) => {
        calls.push({ step: 'revokeSessions', authorization, profileId });
        return Promise.resolve();
      },
      recordAction: (actorId, action, targetId, details) => {
        calls.push({ step: 'recordAction', actorId, action, targetId, details });
        return Promise.resolve();
      },
      ...overrides.accounts,
    },
  });
  const post = (body: unknown, headers: Record<string, string> = { Authorization: 'Bearer user-jwt' }) =>
    handler(
      new Request('http://fn/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Origin: ADMIN_ORIGIN, ...headers },
        body: JSON.stringify(body),
      }),
    );
  return { calls, post, handler };
}

Deno.test('an admin gets a one-time temporary password; the account is updated, signed out everywhere and audited', async () => {
  const { calls, post } = setup();
  const response = await post({ profile_id: PROFILE });
  assertEquals(response.status, 200);
  assertEquals(await response.json(), { temporary_password: 'Temp-Pass-123' });
  assertEquals(response.headers.get('Cache-Control'), 'no-store');
  assertEquals(calls, [
    { step: 'setPassword', profileId: PROFILE, password: 'Temp-Pass-123' },
    { step: 'revokeSessions', authorization: 'Bearer user-jwt', profileId: PROFILE },
    { step: 'recordAction', actorId: ADMIN, action: 'reset_password', targetId: PROFILE, details: { role: 'customer' } },
  ]);
});

Deno.test('barbers can be reset too', async () => {
  const { calls, post } = setup({ roles: { [PROFILE]: 'barber' } });
  assertEquals((await post({ profile_id: PROFILE })).status, 200);
  assertEquals(calls.length, 3);
  assertEquals(calls[2], { step: 'recordAction', actorId: ADMIN, action: 'reset_password', targetId: PROFILE, details: { role: 'barber' } });
});

Deno.test('anyone who is not an admin is refused and nothing changes', async () => {
  const { calls, post } = setup({ admin: false });
  const response = await post({ profile_id: PROFILE });
  assertEquals(response.status, 403);
  assertEquals(await response.json(), { error: 'admin_only' });
  assertEquals(calls.length, 0);
});

Deno.test('a missing or malformed Authorization header is refused', async () => {
  const { calls, post } = setup();
  assertEquals((await post({ profile_id: PROFILE }, {})).status, 403);
  assertEquals((await post({ profile_id: PROFILE }, { Authorization: 'user-jwt' })).status, 403);
  assertEquals(calls.length, 0);
});

Deno.test('a failing admin check refuses instead of resetting', async () => {
  const { calls, post } = setup({ adminId: () => Promise.reject(new Error('rpc down')) });
  assertEquals((await post({ profile_id: PROFILE })).status, 403);
  assertEquals(calls.length, 0);
});

Deno.test('admin accounts cannot be reset through the function', async () => {
  const { calls, post } = setup({ roles: { [PROFILE]: 'admin' } });
  const response = await post({ profile_id: PROFILE });
  assertEquals(response.status, 403);
  assertEquals(await response.json(), { error: 'role_not_resettable' });
  assertEquals(calls.length, 0);
});

Deno.test('unknown and malformed profile ids', async () => {
  const { calls, post } = setup();
  assertEquals((await post({ profile_id: '10000000-0000-0000-0000-0000000000ff' })).status, 404);
  assertEquals((await post({ profile_id: 'not-a-uuid' })).status, 400);
  assertEquals((await post({})).status, 400);
  assertEquals(calls.length, 0);
});

Deno.test('a failed password update answers 502, never returns a password and signs nobody out', async () => {
  const { calls, post } = setup({ accounts: { setPassword: () => Promise.reject(new Error('auth down')) } });
  const response = await post({ profile_id: PROFILE });
  assertEquals(response.status, 502);
  assertEquals(await response.json(), { error: 'password_update_failed' });
  assertEquals(calls.length, 0);
});

Deno.test('a failed sign-out answers 502 and never returns the password', async () => {
  const { calls, post } = setup({ accounts: { revokeSessions: () => Promise.reject(new Error('rpc down')) } });
  const response = await post({ profile_id: PROFILE });
  assertEquals(response.status, 502);
  assertEquals(await response.json(), { error: 'session_revoke_failed' });
  assertEquals(calls.map((c) => c.step), ['setPassword']);
});

Deno.test('a failed audit write answers 502 and never returns the password', async () => {
  const { post } = setup({ accounts: { recordAction: () => Promise.reject(new Error('db down')) } });
  const response = await post({ profile_id: PROFILE });
  assertEquals(response.status, 502);
  assertEquals(await response.json(), { error: 'audit_failed' });
});

Deno.test('other methods are rejected, preflight answers for the admin origin only', async () => {
  const { handler } = setup();
  assertEquals((await handler(new Request('http://fn/', { method: 'GET' }))).status, 405);

  const allowed = await handler(new Request('http://fn/', { method: 'OPTIONS', headers: { Origin: ADMIN_ORIGIN } }));
  assertEquals(allowed.status, 204);
  assertEquals(allowed.headers.get('Access-Control-Allow-Origin'), ADMIN_ORIGIN);

  const other = await handler(
    new Request('http://fn/', { method: 'OPTIONS', headers: { Origin: 'https://evil.example' } }),
  );
  assertEquals(other.headers.get('Access-Control-Allow-Origin'), null);
});

Deno.test('generated passwords are 12 unambiguous characters and differ each time', () => {
  const seen = new Set<string>();
  for (let i = 0; i < 50; i++) {
    const password = temporaryPassword();
    assertMatch(password, /^[A-HJ-NP-Za-km-z2-9]{12}$/);
    seen.add(password);
  }
  assertNotEquals(seen.size, 1);
  assertEquals(seen.size, 50);
});
