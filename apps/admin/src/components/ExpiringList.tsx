'use client';

import { Phone } from 'lucide-react';
import { useState } from 'react';

import { daysFromNow, daysUntil, relativeDays } from '@/lib/format';
import { must } from '@/lib/db';
import { supabase } from '@/lib/supabase';
import type { AdminBarber } from '@/lib/types';
import { useAsync } from '@/lib/useAsync';

import { ActivateDialog } from './ActivateDialog';
import { Avatar, Button, Empty, ErrorNote, Loading, Pill } from './ui';

export function ExpiringList({ days, onChanged }: { days: number; onChanged?: () => void }) {
  const [renewing, setRenewing] = useState<AdminBarber | null>(null);
  const list = useAsync(
    () =>
      must<AdminBarber[]>(
        supabase()
          .from('admin_barbers')
          .select('*')
          .eq('status', 'active')
          .gt('subscription_ends_at', new Date().toISOString())
          .lte('subscription_ends_at', daysFromNow(days))
          .order('subscription_ends_at', { ascending: true }),
      ),
    [days],
  );

  if (list.loading && !list.data) return <Loading />;
  if (list.error) return <ErrorNote message={list.error} onRetry={list.reload} />;
  const rows = list.data ?? [];

  return (
    <>
      {rows.length === 0 ? (
        <Empty>لا توجد اشتراكات تنتهي خلال {days} أيام</Empty>
      ) : (
        <ul>
          {rows.map((barber) => (
            <li key={barber.id} className="flex items-center gap-3 border-b border-line-soft py-3 last:border-0">
              <Avatar name={barber.display_name} />
              <div className="min-w-0 flex-1">
                <div className="truncate font-bold text-ink">{barber.display_name}</div>
                <div className="truncate text-caption text-ink-3">{barber.salon_name}</div>
              </div>
              <Pill tone={daysUntil(barber.subscription_ends_at!) <= 1 ? 'warning' : 'neutral'}>{relativeDays(barber.subscription_ends_at!)}</Pill>
              {barber.phone && (
                <a href={`tel:+${barber.phone}`} aria-label={`اتصال بـ ${barber.display_name}`} className="flex size-9 items-center justify-center rounded-small border border-line text-ink hover:border-blue-900">
                  <Phone size={16} />
                </a>
              )}
              <Button size="sm" variant="accent" onClick={() => setRenewing(barber)}>
                تجديد
              </Button>
            </li>
          ))}
        </ul>
      )}
      {renewing && (
        <ActivateDialog
          barber={renewing}
          onClose={() => setRenewing(null)}
          onDone={() => {
            list.reload();
            onChanged?.();
          }}
        />
      )}
    </>
  );
}
