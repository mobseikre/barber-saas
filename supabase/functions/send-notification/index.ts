import { createClient } from '@supabase/supabase-js';

import { fcmClientFromSecret } from './fcm.ts';
import { createHandler } from './handler.ts';

const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});

Deno.serve(createHandler({
  secret: Deno.env.get('NOTIFICATION_WEBHOOK_SECRET'),
  fcm: fcmClientFromSecret(Deno.env.get('FCM_SERVICE_ACCOUNT'), { apiUrl: Deno.env.get('FCM_API_URL') }),
  tokens: {
    async tokensOf(profileId) {
      const { data, error } = await db.from('device_tokens').select('token').eq('profile_id', profileId);
      if (error) throw error;
      return data.map((row) => row.token);
    },
    async remove(tokens) {
      const { error } = await db.from('device_tokens').delete().in('token', tokens);
      if (error) throw error;
    },
  },
}));
