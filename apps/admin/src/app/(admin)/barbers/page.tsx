'use client';

import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { Suspense, useMemo, useState } from 'react';

import { ActivateDialog } from '@/components/ActivateDialog';
import { ConfirmDialog } from '@/components/Confirm';
import { ResetPasswordDialog } from '@/components/ResetPasswordDialog';
import { Avatar, Badge, BarberStatusBadge, Button, Card, Cell, Chips, Empty, ErrorNote, Loading, Modal, PageHeader, Pill, Row, SearchInput, SubscriptionBadge, Table, useToast } from '@/components/ui';
import { barberSubscription, CANCEL_REASON_LABELS } from '@/lib/barbers';
import { PAGE_SIZE } from '@/lib/constants';
import { must } from '@/lib/db';
import { errorMessage } from '@/lib/errors';
import { formatDate, formatDayMonth, formatTime, rangeStart } from '@/lib/format';
import { formatPhone } from '@/lib/phone';
import { supabase } from '@/lib/supabase';
import type { AdminBarber, BarberStatus, Cancellations, CancelReason } from '@/lib/types';
import { useAsync } from '@/lib/useAsync';
import { useAdmin } from '@/components/AuthProvider';

type StatusFilter = 'all' | BarberStatus;

interface CancelledBooking {
  id: string;
  time_range: string;
  cancel_reason: CancelReason | null;
  cancel_note: string | null;
  customer_name: string | null;
  customer: { full_name: string } | null;
}

function CancellationsDialog({ barber, onClose }: { barber: AdminBarber; onClose: () => void }) {
  const list = useAsync(
    () =>
      must<CancelledBooking[]>(
        supabase()
          .from('bookings')
          .select('id,time_range,cancel_reason,cancel_note,customer_name,customer:profiles!bookings_customer_id_fkey(full_name)')
          .eq('barber_id', barber.id)
          .eq('status', 'cancelled')
          .eq('cancelled_by', barber.profile_id!)
          .order('cancelled_at', { ascending: false })
          .limit(50),
      ),
    [barber.id],
  );

  return (
    <Modal title={`إلغاءات ${barber.display_name}`} onClose={onClose} wide>
      {list.loading && !list.data ? (
        <Loading />
      ) : list.error ? (
        <ErrorNote message={list.error} onRetry={list.reload} />
      ) : (list.data ?? []).length === 0 ? (
        <Empty>لا توجد إلغاءات</Empty>
      ) : (
        <Table head={['موعد الحجز', 'الزبون', 'السبب', 'ملاحظة']}>
          {(list.data ?? []).map((b) => {
            const when = rangeStart(b.time_range);
            return (
              <Row key={b.id}>
                <Cell>{when ? `${formatDayMonth(when)} · ${formatTime(when)}` : '—'}</Cell>
                <Cell>{b.customer?.full_name ?? b.customer_name ?? '—'}</Cell>
                <Cell>{b.cancel_reason ? CANCEL_REASON_LABELS[b.cancel_reason] : '—'}</Cell>
                <Cell>{b.cancel_note ?? '—'}</Cell>
              </Row>
            );
          })}
        </Table>
      )}
    </Modal>
  );
}

function BarbersView() {
  const { notify } = useToast();
  const { refreshCounts } = useAdmin();
  const initial = useSearchParams().get('q') ?? '';
  const [query, setQuery] = useState(initial);
  const [status, setStatus] = useState<StatusFilter>('all');
  const [visible, setVisible] = useState(PAGE_SIZE);
  const [extending, setExtending] = useState<AdminBarber | null>(null);
  const [resetting, setResetting] = useState<AdminBarber | null>(null);
  const [pausing, setPausing] = useState<AdminBarber | null>(null);
  const [cancellations, setCancellations] = useState<AdminBarber | null>(null);

  const data = useAsync(async () => {
    const [barbers, cancelled] = await Promise.all([
      must<AdminBarber[]>(supabase().from('admin_barbers').select('*').order('created_at', { ascending: false }).order('id')),
      must<Cancellations[]>(supabase().from('admin_barber_cancellations').select('barber_id,cancelled_total,sick,emergency,other')),
    ]);
    return { barbers, cancelled: new Map(cancelled.map((c) => [c.barber_id, c])) };
  }, []);

  const rows = useMemo(() => {
    const term = query.trim().replace(/^0/, '');
    return (data.data?.barbers ?? []).filter((b) => (status === 'all' || b.status === status) && (!term || b.display_name.includes(term) || b.salon_name.includes(term) || (b.phone ?? '').includes(term)));
  }, [data.data, query, status]);

  function reload() {
    data.reload();
    refreshCounts();
  }

  async function setBarberStatus(barber: AdminBarber, rpc: 'suspend_barber' | 'reactivate_barber', success: string) {
    const { error } = await supabase().rpc(rpc, { p_barber_id: barber.id });
    if (error) notify(errorMessage(error), 'error');
    else {
      notify(success);
      reload();
    }
  }

  return (
    <>
      <PageHeader title="الحلاقون" subtitle="كل الحلاقين المسجلين مع حالتهم واشتراكهم وإلغاءاتهم" />
      <Card className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Chips
            value={status}
            onChange={(value) => {
              setStatus(value);
              setVisible(PAGE_SIZE);
            }}
            options={[
              { value: 'all', label: 'الكل' },
              { value: 'pending', label: 'بانتظار التفعيل' },
              { value: 'active', label: 'نشط' },
              { value: 'suspended', label: 'موقوف' },
              { value: 'rejected', label: 'مرفوض' },
            ]}
          />
          <SearchInput
            value={query}
            onChange={(value) => {
              setQuery(value);
              setVisible(PAGE_SIZE);
            }}
            placeholder="ابحث باسم حلاق، صالون أو رقم هاتف"
          />
        </div>
        {data.loading && !data.data ? (
          <Loading />
        ) : data.error ? (
          <ErrorNote message={data.error} onRetry={data.reload} />
        ) : (
          <>
            <Table head={['الحلاق', 'الهاتف', 'الحالة', 'الاشتراك', 'إلغاءات الحلاق', 'الإجراء']} empty={rows.length === 0 && <Empty>لا يوجد حلاقون مطابقون</Empty>}>
              {rows.slice(0, visible).map((b) => {
                const cancelled = data.data?.cancelled.get(b.id);
                const hasAccount = !!b.profile_id;
                return (
                  <Row key={b.id}>
                    <Cell>
                      <div className="flex items-center gap-3">
                        <Avatar name={b.display_name} muted={!hasAccount} />
                        <div>
                          <div className="font-bold text-ink">{b.display_name}</div>
                          <div className="text-caption text-ink-3">{b.salon_name}</div>
                        </div>
                      </div>
                    </Cell>
                    <Cell>
                      <span dir="ltr" className="inline-block whitespace-nowrap">{formatPhone(b.phone)}</span>
                    </Cell>
                    <Cell>{hasAccount ? <BarberStatusBadge status={b.status} /> : <Badge tone="neutral">بلا حساب</Badge>}</Cell>
                    <Cell>
                      <div className="flex flex-col items-start gap-1">
                        <SubscriptionBadge state={barberSubscription(b)} />
                        {b.subscription_ends_at && <span className="text-caption text-ink-3">حتى {formatDate(b.subscription_ends_at)}</span>}
                      </div>
                    </Cell>
                    <Cell>
                      {cancelled && cancelled.cancelled_total > 0 ? (
                        <button type="button" onClick={() => setCancellations(b)} className="flex flex-col items-start gap-1 text-start" aria-label={`إلغاءات ${b.display_name}`}>
                          <span className="font-bold text-red-700 underline">{cancelled.cancelled_total}</span>
                          <span className="flex gap-1">
                            {cancelled.sick > 0 && <Pill tone="neutral">مريض {cancelled.sick}</Pill>}
                            {cancelled.emergency > 0 && <Pill tone="neutral">طارئ {cancelled.emergency}</Pill>}
                            {cancelled.other > 0 && <Pill tone="neutral">أخرى {cancelled.other}</Pill>}
                          </span>
                        </button>
                      ) : (
                        <span className="text-ink-3">0</span>
                      )}
                    </Cell>
                    <Cell>
                      <div className="flex flex-wrap gap-2">
                        {b.status === 'pending' && (
                          <Link href="/activation" className="inline-flex h-9 items-center rounded-small bg-blue-900 px-3 text-[14px] font-bold text-white hover:bg-blue-pressed">
                            مراجعة الطلب
                          </Link>
                        )}
                        {hasAccount && b.status !== 'rejected' && b.status !== 'pending' && (
                          <Button size="sm" onClick={() => setExtending(b)}>
                            {b.subscription_ends_at ? 'تمديد' : 'تفعيل اشتراك'}
                          </Button>
                        )}
                        {b.status === 'active' && hasAccount && (
                          <Button size="sm" variant="danger" onClick={() => setPausing(b)}>
                            إيقاف
                          </Button>
                        )}
                        {b.status === 'suspended' && (
                          <Button size="sm" variant="secondary" onClick={() => setBarberStatus(b, 'reactivate_barber', 'تمت إعادة التفعيل')}>
                            إعادة تفعيل
                          </Button>
                        )}
                        {hasAccount && (
                          <Button size="sm" variant="secondary" onClick={() => setResetting(b)}>
                            كلمة المرور
                          </Button>
                        )}
                      </div>
                    </Cell>
                  </Row>
                );
              })}
            </Table>
            {rows.length > visible && (
              <Button variant="secondary" className="self-center" onClick={() => setVisible((n) => n + PAGE_SIZE)}>
                عرض المزيد ({rows.length - visible})
              </Button>
            )}
          </>
        )}
      </Card>

      {extending && <ActivateDialog barber={extending} onClose={() => setExtending(null)} onDone={reload} />}
      {resetting && <ResetPasswordDialog target={{ profile_id: resetting.profile_id!, name: resetting.display_name, phone: resetting.phone }} onClose={() => setResetting(null)} />}
      {cancellations && <CancellationsDialog barber={cancellations} onClose={() => setCancellations(null)} />}
      {pausing && (
        <ConfirmDialog title={`إيقاف ${pausing.display_name}؟`} confirmLabel="إيقاف الحلاق" danger onConfirm={() => setBarberStatus(pausing, 'suspend_barber', 'تم إيقاف الحلاق')} onClose={() => setPausing(null)}>
          لن يظهر في البحث ولن يمكن الحجز معه حتى تعيد تفعيله.
        </ConfirmDialog>
      )}
    </>
  );
}

export default function BarbersPage() {
  return (
    <Suspense>
      <BarbersView />
    </Suspense>
  );
}
