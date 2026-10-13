import type { PushMessage } from './messages.ts';

/** The fields of a Google service account key that FCM needs. */
export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri: string;
}

export type SendResult = 'sent' | 'unregistered' | 'failed';

const scope = 'https://www.googleapis.com/auth/firebase.messaging';
const goneTokenCodes = ['UNREGISTERED', 'SENDER_ID_MISMATCH', 'INVALID_ARGUMENT'];

function base64Url(bytes: Uint8Array | string): string {
  const data = typeof bytes === 'string' ? new TextEncoder().encode(bytes) : bytes;
  return btoa(String.fromCharCode(...data)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

function parseJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

/** A client for the service account in the `FCM_SERVICE_ACCOUNT` secret, or null when it is missing or invalid. */
export function fcmClientFromSecret(secret: string | undefined, options: { apiUrl?: string } = {}): FcmClient | null {
  if (!secret) return null;
  const account = parseJson(secret) as Partial<ServiceAccount> | null;
  const fields = ['project_id', 'client_email', 'private_key', 'token_uri'] as const;
  if (!fields.every((f) => typeof account?.[f] === 'string' && account[f])) {
    console.error('fcm_service_account_invalid');
    return null;
  }
  return new FcmClient(account as ServiceAccount, options);
}

/** Sends messages with the FCM HTTP v1 API, signing in with a service account. */
export class FcmClient {
  #account: ServiceAccount;
  #apiUrl: string;
  #accessToken?: { value: string; expiresAt: number };
  #pendingToken?: Promise<string>;

  constructor(account: ServiceAccount, { apiUrl = 'https://fcm.googleapis.com' }: { apiUrl?: string } = {}) {
    this.#account = account;
    this.#apiUrl = apiUrl.replace(/\/$/, '');
  }

  async send(token: string, message: PushMessage): Promise<SendResult> {
    let response = await this.#post(token, message);
    if (response.status === 401) {
      this.#accessToken = undefined;
      response = await this.#post(token, message);
    }
    if (response.ok) {
      await response.body?.cancel();
      return 'sent';
    }
    const error = await response.json().catch(() => null);
    const codes: string[] = (error?.error?.details ?? []).map((d: { errorCode?: string }) => d.errorCode);
    if (response.status === 404 || codes.some((c) => goneTokenCodes.includes(c))) return 'unregistered';
    console.error('fcm_send_failed', response.status, JSON.stringify(error));
    return 'failed';
  }

  async #post(token: string, message: PushMessage): Promise<Response> {
    return fetch(`${this.#apiUrl}/v1/projects/${this.#account.project_id}/messages:send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${await this.#token()}` },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: message.title, body: message.body },
          data: message.data,
          android: { priority: 'high', notification: { sound: 'default' } },
          apns: { payload: { aps: { sound: 'default' } } },
        },
      }),
    });
  }

  #token(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (this.#accessToken && this.#accessToken.expiresAt - 60 > now) return Promise.resolve(this.#accessToken.value);
    this.#pendingToken ??= this.#signIn(now).finally(() => this.#pendingToken = undefined);
    return this.#pendingToken;
  }

  async #signIn(now: number): Promise<string> {
    const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
    const claims = base64Url(JSON.stringify({
      iss: this.#account.client_email,
      scope,
      aud: this.#account.token_uri,
      iat: now,
      exp: now + 3600,
    }));
    const key = await crypto.subtle.importKey(
      'pkcs8',
      pemToDer(this.#account.private_key),
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      key,
      new TextEncoder().encode(`${header}.${claims}`),
    );
    const assertion = `${header}.${claims}.${base64Url(new Uint8Array(signature))}`;

    const response = await fetch(this.#account.token_uri, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
    });
    if (!response.ok) throw new Error(`fcm_auth_failed ${response.status} ${await response.text()}`);
    const { access_token, expires_in } = await response.json();
    this.#accessToken = { value: access_token, expiresAt: now + expires_in };
    return access_token;
  }
}
