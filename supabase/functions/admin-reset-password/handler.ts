export interface ResetDeps {
  allowedOrigins: string[];
  /** The caller's own identity, through their JWT and RLS: their profile id when they are an admin. */
  adminId(authorization: string): Promise<string | null>;
  /** Service role access, used only after `adminId` passed. */
  accounts: {
    roleOf(profileId: string): Promise<string | null>;
    /** Sets the password and `app_metadata.must_change_password`. */
    setPassword(profileId: string, password: string): Promise<void>;
    /** Signs the target out everywhere, through the caller's JWT. */
    revokeSessions(authorization: string, profileId: string): Promise<void>;
    recordAction(actorId: string, action: string, targetId: string, details: Record<string, unknown>): Promise<void>;
  };
  generatePassword?: () => string;
}

const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
const PASSWORD_LENGTH = 12;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function temporaryPassword(): string {
  const limit = 256 - (256 % ALPHABET.length);
  let out = '';
  while (out.length < PASSWORD_LENGTH) {
    for (const byte of crypto.getRandomValues(new Uint8Array(PASSWORD_LENGTH * 2))) {
      if (byte < limit && out.length < PASSWORD_LENGTH) out += ALPHABET[byte % ALPHABET.length];
    }
  }
  return out;
}

export function createHandler(deps: ResetDeps) {
  const generate = deps.generatePassword ?? temporaryPassword;

  return async (request: Request): Promise<Response> => {
    const origin = request.headers.get('Origin');
    const cors: Record<string, string> = {
      'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      Vary: 'Origin',
    };
    if (origin && deps.allowedOrigins.includes(origin)) cors['Access-Control-Allow-Origin'] = origin;
    const json = (body: unknown, status = 200) =>
      new Response(JSON.stringify(body), {
        status,
        headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...cors },
      });

    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

    const authorization = request.headers.get('Authorization') ?? '';
    const actorId = authorization.startsWith('Bearer ') ? await deps.adminId(authorization).catch(() => null) : null;
    if (!actorId) return json({ error: 'admin_only' }, 403);

    const body = await request.json().catch(() => null);
    const profileId = body?.profile_id;
    if (typeof profileId !== 'string' || !UUID.test(profileId)) return json({ error: 'invalid_profile' }, 400);

    const role = await deps.accounts.roleOf(profileId);
    if (!role) return json({ error: 'profile_not_found' }, 404);
    if (role !== 'barber' && role !== 'customer') return json({ error: 'role_not_resettable' }, 403);

    const password = generate();
    try {
      await deps.accounts.setPassword(profileId, password);
    } catch (error) {
      console.error('password_update_failed', error);
      return json({ error: 'password_update_failed' }, 502);
    }
    try {
      await deps.accounts.revokeSessions(authorization, profileId);
    } catch (error) {
      console.error('session_revoke_failed', error);
      return json({ error: 'session_revoke_failed' }, 502);
    }
    try {
      await deps.accounts.recordAction(actorId, 'reset_password', profileId, { role });
    } catch (error) {
      console.error('audit_failed', error);
      return json({ error: 'audit_failed' }, 502);
    }
    return json({ temporary_password: password });
  };
}
