import { assertEquals } from '@std/assert';

import { FcmClient, fcmClientFromSecret } from './fcm.ts';
import { createHandler, type TokenStore } from './handler.ts';
import { type ActivationPayload, composeMessage, type NotificationPayload } from './messages.ts';

const created: NotificationPayload = {
  type: 'booking_created',
  booking_id: 'b1',
  recipient_id: 'barber-1',
  audience: 'barber',
  starts_at: '2026-10-15T17:30:00+00:00',
  barber_name: 'علي القماطي',
  salon_name: 'صالون الأناقة',
  customer_name: 'خالد المقريف',
  service_name: 'قص شعر',
};

Deno.test('messages are Arabic, in Tripoli time, with Latin digits', () => {
  const cancelled = { ...created, type: 'booking_cancelled' as const };
  const toCustomer = { ...cancelled, audience: 'customer' as const, recipient_id: 'customer-1' };
  const cases: [NotificationPayload, string, string][] = [
    [created, 'حجز جديد', 'خالد المقريف حجز قص شعر يوم الخميس، 15 أكتوبر الساعة 7:30 م'],
    [
      { ...cancelled, cancelled_by: 'customer' },
      'تم إلغاء حجز',
      'ألغى خالد المقريف حجز قص شعر يوم الخميس، 15 أكتوبر الساعة 7:30 م',
    ],
    [
      { ...toCustomer, cancelled_by: 'barber', cancel_reason: 'sick', cancel_note: 'حرارة' },
      'تم إلغاء موعدك',
      'ألغى علي القماطي موعدك يوم الخميس، 15 أكتوبر الساعة 7:30 م. السبب: مريض — حرارة',
    ],
    [
      { ...toCustomer, cancelled_by: 'barber', cancel_reason: 'other', cancel_note: 'سفر' },
      'تم إلغاء موعدك',
      'ألغى علي القماطي موعدك يوم الخميس، 15 أكتوبر الساعة 7:30 م. السبب: سفر',
    ],
    [
      { ...toCustomer, cancelled_by: 'barber', cancel_reason: 'emergency' },
      'تم إلغاء موعدك',
      'ألغى علي القماطي موعدك يوم الخميس، 15 أكتوبر الساعة 7:30 م. السبب: ظرف طارئ',
    ],
    [
      { ...toCustomer, cancelled_by: 'admin' },
      'تم إلغاء موعدك',
      'ألغت الإدارة موعدك مع علي القماطي يوم الخميس، 15 أكتوبر الساعة 7:30 م.',
    ],
    [
      { ...cancelled, cancelled_by: 'admin' },
      'تم إلغاء حجز',
      'ألغت الإدارة حجز خالد المقريف يوم الخميس، 15 أكتوبر الساعة 7:30 م',
    ],
    [
      { ...toCustomer, type: 'booking_reminder', starts_at: '2026-10-15T07:05:00Z' },
      'تذكير بموعدك',
      'موعدك مع علي القماطي في صالون الأناقة الساعة 9:05 ص',
    ],
  ];
  for (const [payload, title, body] of cases) {
    assertEquals(composeMessage(payload), { title, body, data: { type: payload.type, booking_id: 'b1' } });
  }
});

Deno.test('an activated barber hears whether customers can book them now', () => {
  const activated: ActivationPayload = {
    type: 'barber_activated',
    recipient_id: 'barber-1',
    audience: 'barber',
    barber_name: 'علي القماطي',
    bookable: true,
    renewed: false,
  };
  const data = { type: 'barber_activated' };
  assertEquals(composeMessage(activated), {
    title: 'تم تفعيل حسابك',
    body: 'حسابك ظاهر للزبائن الآن ويمكنهم الحجز عندك.',
    data,
  });
  assertEquals(composeMessage({ ...activated, renewed: true }), {
    title: 'تم تجديد اشتراكك',
    body: 'عاد حسابك للظهور للزبائن ويمكنهم الحجز عندك الآن.',
    data,
  });
  assertEquals(composeMessage({ ...activated, bookable: false }), {
    title: 'تم تفعيل حسابك',
    body: 'فعّل اشتراكك مع الإدارة ليظهر حسابك للزبائن ويحجزوا عندك.',
    data,
  });
  assertEquals(composeMessage({ ...activated, audience: 'customer' }), null);
  assertEquals(composeMessage({ ...activated, recipient_id: undefined }), null);
});

Deno.test('unknown or incomplete payloads have no message', () => {
  assertEquals(composeMessage(null), null);
  assertEquals(composeMessage({ ...created, type: 'something_else' }), null);
  assertEquals(composeMessage({ ...created, audience: undefined }), null);
  assertEquals(composeMessage({ ...created, starts_at: 'soon' }), null);
});

// A stand-in for Google's OAuth token endpoint and the FCM v1 API.
async function fakeGoogle() {
  const keys = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  );
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey('pkcs8', keys.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...pkcs8))}\n-----END PRIVATE KEY-----\n`;
  const fromBase64Url = (s: string) =>
    Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));

  const state = { tokenRequests: 0, messages: [] as { auth: string | null; message: Record<string, unknown> }[] };
  const server = Deno.serve({ port: 0, hostname: '127.0.0.1', onListen() {} }, async (request) => {
    const url = new URL(request.url);
    if (url.pathname === '/token') {
      state.tokenRequests++;
      const form = new URLSearchParams(await request.text());
      const [header, claims, signature] = form.get('assertion')!.split('.');
      const valid = await crypto.subtle.verify(
        'RSASSA-PKCS1-v1_5',
        keys.publicKey,
        fromBase64Url(signature),
        new TextEncoder().encode(`${header}.${claims}`),
      );
      const c = JSON.parse(new TextDecoder().decode(fromBase64Url(claims)));
      if (
        !valid || c.iss !== 'push@demo.iam.gserviceaccount.com' || c.aud !== `${base}/token` ||
        c.scope !== 'https://www.googleapis.com/auth/firebase.messaging'
      ) {
        return Response.json({ error: 'invalid_grant' }, { status: 400 });
      }
      return Response.json({ access_token: 'fake-access-token', expires_in: 3600 });
    }
    if (url.pathname === '/v1/projects/demo/messages:send') {
      const { message } = await request.json();
      state.messages.push({ auth: request.headers.get('Authorization'), message });
      if (message.token === 'stale-token') {
        return Response.json({
          error: {
            code: 404,
            status: 'NOT_FOUND',
            details: [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: 'UNREGISTERED' }],
          },
        }, { status: 404 });
      }
      if (message.token === 'invalid-token') {
        return Response.json({
          error: {
            code: 400,
            status: 'INVALID_ARGUMENT',
            details: [{
              '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
              errorCode: 'INVALID_ARGUMENT',
            }],
          },
        }, { status: 400 });
      }
      if (message.token === 'broken-token') return Response.json({ error: { code: 500 } }, { status: 500 });
      return Response.json({ name: 'projects/demo/messages/1' });
    }
    return new Response('not found', { status: 404 });
  });
  const base = `http://127.0.0.1:${server.addr.port}`;
  const fcm = new FcmClient(
    {
      project_id: 'demo',
      client_email: 'push@demo.iam.gserviceaccount.com',
      private_key: pem,
      token_uri: `${base}/token`,
    },
    { apiUrl: base },
  );
  const account = JSON.stringify({
    type: 'service_account',
    project_id: 'demo',
    client_email: 'push@demo.iam.gserviceaccount.com',
    private_key: pem,
    token_uri: `${base}/token`,
  });
  return { fcm, account, base, state, close: () => server.shutdown() };
}

class MemoryTokens implements TokenStore {
  constructor(public rows: Record<string, string[]>) {}
  tokensOf(profileId: string) {
    return Promise.resolve(this.rows[profileId] ?? []);
  }
  remove(tokens: string[]) {
    for (const id in this.rows) this.rows[id] = this.rows[id].filter((t) => !tokens.includes(t));
    return Promise.resolve();
  }
}

const post = (body: unknown, secret = 'test-secret') =>
  new Request('http://localhost/send-notification', {
    method: 'POST',
    headers: { Authorization: `Bearer ${secret}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

Deno.test('sends to every device of the recipient through FCM v1 and drops unregistered tokens', async () => {
  const google = await fakeGoogle();
  try {
    const tokens = new MemoryTokens({ 'barber-1': ['phone-token', 'stale-token', 'broken-token'], 'other': ['x'] });
    const handle = createHandler({ secret: 'test-secret', tokens, fcm: google.fcm });

    const response = await handle(post(created));
    assertEquals(response.status, 200);
    assertEquals(await response.json(), { sent: 1, failed: 1, removed: 1 });
    assertEquals(tokens.rows, { 'barber-1': ['phone-token', 'broken-token'], 'other': ['x'] });

    const sent = google.state.messages.find((m) => m.message.token === 'phone-token')!;
    assertEquals(sent.auth, 'Bearer fake-access-token');
    assertEquals(sent.message, {
      token: 'phone-token',
      notification: { title: 'حجز جديد', body: 'خالد المقريف حجز قص شعر يوم الخميس، 15 أكتوبر الساعة 7:30 م' },
      data: { type: 'booking_created', booking_id: 'b1' },
      android: { priority: 'high', notification: { sound: 'default' } },
      apns: { payload: { aps: { sound: 'default' } } },
    });

    await (await handle(post(created))).body?.cancel();
    assertEquals(google.state.tokenRequests, 1, 'the access token is reused until it expires');
  } finally {
    await google.close();
  }
});

Deno.test('rejects requests without the shared secret', async () => {
  const google = await fakeGoogle();
  try {
    const tokens = new MemoryTokens({ 'barber-1': ['phone-token'] });
    for (
      const handle of [
        createHandler({ secret: 'test-secret', tokens, fcm: google.fcm }),
        createHandler({ secret: undefined, tokens, fcm: google.fcm }),
      ]
    ) {
      const wrong = await handle(post(created, 'guess'));
      assertEquals(wrong.status, 401);
      await wrong.body?.cancel();
    }
    assertEquals(google.state.messages.length, 0);
  } finally {
    await google.close();
  }
});

Deno.test('answers without calling FCM when there is nothing to send', async () => {
  const google = await fakeGoogle();
  try {
    const handle = createHandler({ secret: 'test-secret', tokens: new MemoryTokens({}), fcm: google.fcm });

    const noDevice = await handle(post(created));
    assertEquals(await noDevice.json(), { sent: 0, failed: 0, removed: 0 });

    const invalid = await handle(post({ type: 'booking_created' }));
    assertEquals(invalid.status, 400);
    await invalid.body?.cancel();

    assertEquals(google.state.tokenRequests, 0);
    assertEquals(google.state.messages.length, 0);
  } finally {
    await google.close();
  }
});

Deno.test('reports a missing service account instead of dropping the message silently', async () => {
  const handle = createHandler({ secret: 'test-secret', tokens: new MemoryTokens({ 'barber-1': ['t'] }), fcm: null });
  const response = await handle(post(created));
  assertEquals(response.status, 503);
  assertEquals(await response.json(), { error: 'fcm_not_configured' });
});

Deno.test('a token FCM rejects as INVALID_ARGUMENT is treated as unregistered and deleted', async () => {
  const google = await fakeGoogle();
  try {
    const tokens = new MemoryTokens({ 'barber-1': ['phone-token', 'invalid-token'] });
    const handle = createHandler({ secret: 'test-secret', tokens, fcm: google.fcm });

    const response = await handle(post(created));
    assertEquals(await response.json(), { sent: 1, failed: 0, removed: 1 });
    assertEquals(tokens.rows, { 'barber-1': ['phone-token'] });
  } finally {
    await google.close();
  }
});

Deno.test('answers 502 when no device received the message, so the outbox retries', async () => {
  const google = await fakeGoogle();
  try {
    const tokens = new MemoryTokens({ 'barber-1': ['broken-token'] });
    const handle = createHandler({ secret: 'test-secret', tokens, fcm: google.fcm });

    const response = await handle(post(created));
    assertEquals(response.status, 502);
    assertEquals(await response.json(), { sent: 0, failed: 1, removed: 0 });
  } finally {
    await google.close();
  }
});

Deno.test('a malformed FCM_SERVICE_ACCOUNT secret answers 503 instead of crashing', async () => {
  const errors: unknown[][] = [];
  const consoleError = console.error;
  console.error = (...args: unknown[]) => errors.push(args);
  try {
    for (const secret of ['{"project_id": "demo",', '"just a string"', '{"project_id": "demo"}', 'null']) {
      const fcm = fcmClientFromSecret(secret);
      assertEquals(fcm, null, secret);
      const handle = createHandler({ secret: 'test-secret', tokens: new MemoryTokens({ 'barber-1': ['t'] }), fcm });
      const response = await handle(post(created));
      assertEquals(response.status, 503, secret);
      assertEquals(await response.json(), { error: 'fcm_not_configured' });
    }
    assertEquals(fcmClientFromSecret(undefined), null);
    assertEquals(fcmClientFromSecret(''), null);
  } finally {
    console.error = consoleError;
  }
  assertEquals(errors.filter(([e]) => e === 'fcm_service_account_invalid').length, 4);
});

Deno.test('a valid FCM_SERVICE_ACCOUNT secret sends', async () => {
  const google = await fakeGoogle();
  try {
    const fcm = fcmClientFromSecret(google.account, { apiUrl: google.base });
    const handle = createHandler({
      secret: 'test-secret',
      tokens: new MemoryTokens({ 'barber-1': ['phone-token'] }),
      fcm,
    });
    assertEquals(await (await handle(post(created))).json(), { sent: 1, failed: 0, removed: 0 });
  } finally {
    await google.close();
  }
});
