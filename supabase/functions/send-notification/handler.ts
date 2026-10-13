import { composeMessage, type NotificationPayload, type PushMessage } from './messages.ts';
import type { SendResult } from './fcm.ts';

export interface TokenStore {
  tokensOf(profileId: string): Promise<string[]>;
  remove(tokens: string[]): Promise<void>;
}

export interface Sender {
  send(token: string, message: PushMessage): Promise<SendResult>;
}

export interface HandlerDeps {
  /** Shared with Postgres through Vault (`notification_webhook_secret`). */
  secret: string | undefined;
  tokens: TokenStore;
  /** Null until a valid FCM service account is set. */
  fcm: Sender | null;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

function sameSecret(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

export function createHandler({ secret, tokens, fcm }: HandlerDeps) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
    if (!secret || !sameSecret(request.headers.get('Authorization') ?? '', `Bearer ${secret}`)) {
      return json({ error: 'unauthorized' }, 401);
    }

    const payload = await request.json().catch(() => null);
    const message = composeMessage(payload);
    if (!message) return json({ error: 'invalid_payload' }, 400);

    const recipientTokens = await tokens.tokensOf((payload as NotificationPayload).recipient_id);
    if (recipientTokens.length === 0) return json({ sent: 0, failed: 0, removed: 0 });
    if (!fcm) {
      console.error('fcm_not_configured');
      return json({ error: 'fcm_not_configured' }, 503);
    }

    const results = await Promise.all(recipientTokens.map((t) => fcm.send(t, message).catch(() => 'failed' as const)));
    const gone = recipientTokens.filter((_, i) => results[i] === 'unregistered');
    if (gone.length > 0) await tokens.remove(gone);
    const sent = results.filter((r) => r === 'sent').length;
    const failed = results.filter((r) => r === 'failed').length;
    return json({ sent, failed, removed: gone.length }, sent === 0 && failed > 0 ? 502 : 200);
  };
}
