import { createClient } from '@supabase/supabase-js';

import { createHandler } from './handler.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const service = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });

const asCaller = (authorization: string) =>
  createClient(url, anonKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });

Deno.serve(createHandler({
  allowedOrigins: (Deno.env.get('ADMIN_ALLOWED_ORIGINS') ?? 'http://localhost:3000,http://127.0.0.1:3000')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
  async adminId(authorization) {
    const caller = asCaller(authorization);
    const { data, error } = await caller.rpc('is_admin');
    if (error) throw error;
    if (data !== true) return null;
    const { data: { user }, error: userError } = await caller.auth.getUser(authorization.slice('Bearer '.length));
    if (userError) throw userError;
    return user?.id ?? null;
  },
  accounts: {
    async roleOf(profileId) {
      const { data, error } = await service.from('profiles').select('role').eq('id', profileId).maybeSingle();
      if (error) throw error;
      return data?.role ?? null;
    },
    async setPassword(profileId, password) {
      const { error } = await service.auth.admin.updateUserById(profileId, {
        password,
        app_metadata: { must_change_password: true },
      });
      if (error) throw error;
    },
    async revokeSessions(authorization, profileId) {
      const { error } = await asCaller(authorization).rpc('admin_revoke_sessions', { p_profile_id: profileId });
      if (error) throw error;
    },
    async recordAction(actorId, action, targetId, details) {
      const { error } = await service.from('admin_actions').insert({ actor_id: actorId, action, target_id: targetId, details });
      if (error) throw error;
    },
  },
}));
