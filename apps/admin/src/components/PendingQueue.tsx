'use client';

import { useState } from 'react';

import { formatDate, formatTime, tripoliDay } from '@/lib/format';
import { errorMessage } from '@/lib/errors';
import { formatPhone } from '@/lib/phone';
import { must } from '@/lib/db';
import { supabase } from '@/lib/supabase';
import type { AdminBarber } from '@/lib/types';
import { useAsync } from '@/lib/useAsync';

import { ApproveDialog } from './ApproveDialog';
import { useAdmin } from './AuthProvider';
import { ConfirmDialog } from './Confirm';
import { Avatar, Badge, Button, Cell, Empty, ErrorNote, Loading, Pill, Row, Table, useToast } from './ui';

export function registeredLabel(createdAt: string): string {
  if (tripoliDay(createdAt) === tripoliDay()) return `اليوم ${formatTime(createdAt)}`;
  return formatDate(createdAt);
}

export function PendingQueue({ limit, status = 'pending', onChanged }: { limit?: number; status?: 'pending' | 'rejected'; onChanged?: () => void }) {
  const { notify } = useToast();
  const { refreshCounts } = useAdmin();
  const [approving, setApproving] = useState<AdminBarber | null>(null);
  const [rejecting, setRejecting] = useState<AdminBarber | null>(null);
  const compact = !!limit;

  const list = useAsync(async () => {
    let query = supabase().from('admin_barbers').select('*').eq('status', status).order('created_at', { ascending: true });
    if (limit) query = query.limit(limit);
    return must<AdminBarber[]>(query);
  }, [limit, status]);

  function changed() {
    list.reload();
    refreshCounts();
    onChanged?.();
  }

  async function reject(barber: AdminBarber) {
    const { error } = await supabase().rpc('reject_barber', { p_barber_id: barber.id });
    if (error) notify(errorMessage(error), 'error');
    else {
      notify(`تم رفض ${barber.display_name}`);
      changed();
    }
  }

  if (list.loading && !list.data) return <Loading />;
  if (list.error) return <ErrorNote message={list.error} onRetry={list.reload} />;
  const rows = list.data ?? [];

  return (
    <>
      <Table compact={compact} head={compact ? ['الحلاق', 'الصالون', 'التسجيل', 'الإجراء'] : ['الحلاق', 'الهاتف', 'الصالون', 'التسجيل', 'الإجراء']} empty={rows.length === 0 && <Empty>{status === 'pending' ? 'لا توجد طلبات بانتظار التفعيل' : 'لا يوجد حلاقون مرفوضون'}</Empty>}>
        {rows.map((barber) => (
          <Row key={barber.id}>
            <Cell>
              <div className="flex items-center gap-3">
                <Avatar name={barber.display_name} />
                <div>
                  <div className="font-bold text-ink">{barber.display_name}</div>
                  {compact && (
                    <div dir="ltr" className="text-end text-caption text-ink-3">
                      {formatPhone(barber.phone)}
                    </div>
                  )}
                </div>
              </div>
            </Cell>
            {!compact && (
              <Cell>
                <span dir="ltr" className="inline-block whitespace-nowrap">{formatPhone(barber.phone)}</span>
              </Cell>
            )}
            <Cell>
              <div className="font-semibold text-ink">{barber.salon_name}</div>
              <div className="mt-1">
                <Pill tone={barber.is_salon_owner ? 'danger' : 'info'}>{barber.is_salon_owner ? 'صالون جديد' : 'صالون مسجل'}</Pill>
              </div>
            </Cell>
            <Cell>{registeredLabel(barber.created_at)}</Cell>
            <Cell>
              {status === 'pending' ? (
                <div className="flex flex-wrap gap-2">
                  <Button size="sm" onClick={() => setApproving(barber)}>
                    تفعيل وتحديد الباقة
                  </Button>
                  <Button size="sm" variant="danger" onClick={() => setRejecting(barber)}>
                    رفض
                  </Button>
                </div>
              ) : (
                <Badge tone="danger">مرفوض</Badge>
              )}
            </Cell>
          </Row>
        ))}
      </Table>
      {approving && <ApproveDialog barber={approving} onClose={() => setApproving(null)} onDone={changed} />}
      {rejecting && (
        <ConfirmDialog title={`رفض ${rejecting.display_name}؟`} confirmLabel="رفض الطلب" danger onConfirm={() => reject(rejecting)} onClose={() => setRejecting(null)}>
          لن يتمكن الحلاق من استقبال الحجوزات ولن يظهر للزبائن.
        </ConfirmDialog>
      )}
    </>
  );
}
