'use client';

import { useState } from 'react';

import { Button, Card, Cell, Chips, Empty, ErrorNote, Loading, PageHeader, Row, Table } from '@/components/ui';
import { AUDIT_FILTERS, describeAction, type AuditKind } from '@/lib/audit';
import { PAGE_SIZE, planLabel } from '@/lib/constants';
import { must } from '@/lib/db';
import { formatDate, formatTime } from '@/lib/format';
import { supabase } from '@/lib/supabase';
import type { AdminAction } from '@/lib/types';
import { useAsync } from '@/lib/useAsync';

const BARBER_ACTIONS: AuditKind[] = ['set_barber_status', 'activate_subscription'];
const PROFILE_ACTIONS: AuditKind[] = ['unblock_customer', 'reset_password'];

async function loadLog(filter: AuditKind | 'all', limit: number) {
  const db = supabase();
  let request = db.from('admin_actions').select('id,actor_id,action,target_id,details,created_at,actor:profiles(full_name)');
  if (filter !== 'all') request = request.eq('action', filter);
  const actions = await must<AdminAction[]>(request.order('created_at', { ascending: false }).limit(limit + 1));

  const ids = (kinds: AuditKind[]) => [...new Set(actions.filter((a) => kinds.includes(a.action) && a.target_id).map((a) => a.target_id!))];
  const barberIds = ids(BARBER_ACTIONS);
  const profileIds = ids(PROFILE_ACTIONS);
  const [barbers, profiles] = await Promise.all([
    barberIds.length ? must<{ id: string; display_name: string }[]>(db.from('admin_barbers').select('id,display_name').in('id', barberIds)) : [],
    profileIds.length ? must<{ id: string; full_name: string }[]>(db.from('profiles').select('id,full_name').in('id', profileIds)) : [],
  ]);
  const names = new Map<string, string>([...barbers.map((b) => [b.id, b.display_name] as const), ...profiles.map((p) => [p.id, p.full_name] as const)]);
  return { actions, names };
}

function targetName(action: AdminAction, names: Map<string, string>): string {
  if (action.action === 'save_subscription_plan') return `باقة ${planLabel(Number(action.details.months))}`;
  return (action.target_id && names.get(action.target_id)) || '—';
}

export default function AuditPage() {
  const [filter, setFilter] = useState<AuditKind | 'all'>('all');
  const [limit, setLimit] = useState(PAGE_SIZE);
  const log = useAsync(() => loadLog(filter, limit), [filter, limit]);
  const rows = (log.data?.actions ?? []).slice(0, limit);

  return (
    <>
      <PageHeader title="سجل الإجراءات" subtitle="كل إجراء قامت به الإدارة، مع من قام به ومتى" />
      <Card className="flex flex-col gap-4">
        <Chips
          value={filter}
          onChange={(value) => {
            setFilter(value);
            setLimit(PAGE_SIZE);
          }}
          options={AUDIT_FILTERS}
        />
        {log.loading && !log.data ? (
          <Loading />
        ) : log.error ? (
          <ErrorNote message={log.error} onRetry={log.reload} />
        ) : (
          <>
            <Table head={['الوقت', 'المسؤول', 'الإجراء', 'على', 'التفاصيل']} empty={rows.length === 0 && <Empty>لا توجد إجراءات مسجّلة</Empty>}>
              {rows.map((action) => {
                const { label, details } = describeAction(action);
                return (
                  <Row key={action.id}>
                    <Cell className="whitespace-nowrap">
                      <div className="text-ink">{formatDate(action.created_at)}</div>
                      <div dir="ltr" className="text-end text-caption text-ink-3">
                        {formatTime(action.created_at)}
                      </div>
                    </Cell>
                    <Cell>{action.actor?.full_name ?? '—'}</Cell>
                    <Cell className="font-bold text-ink">{label}</Cell>
                    <Cell className="text-ink">{targetName(action, log.data!.names)}</Cell>
                    <Cell>{details || '—'}</Cell>
                  </Row>
                );
              })}
            </Table>
            {(log.data?.actions ?? []).length > limit && (
              <Button variant="secondary" className="self-center" onClick={() => setLimit((n) => n + PAGE_SIZE)}>
                عرض المزيد
              </Button>
            )}
          </>
        )}
      </Card>
    </>
  );
}
