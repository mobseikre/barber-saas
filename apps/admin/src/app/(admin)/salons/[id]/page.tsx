'use client';

import { Check, Clock, Plus, User } from 'lucide-react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useMemo, useState } from 'react';

import { ActivateDialog } from '@/components/ActivateDialog';
import { ConfirmDialog } from '@/components/Confirm';
import { Avatar, Button, Card, Cell, Chips, Empty, ErrorNote, Field, Input, Loading, Modal, Row, SubscriptionBadge, Table, useToast, BarberStatusBadge } from '@/components/ui';
import { barberSubscription } from '@/lib/barbers';
import { must } from '@/lib/db';
import { errorMessage } from '@/lib/errors';
import { formatDate, formatDayMonth, tripoliDay } from '@/lib/format';
import { formatPhone } from '@/lib/phone';
import { supabase } from '@/lib/supabase';
import type { AdminBarber, AdminSalon } from '@/lib/types';
import { useAsync } from '@/lib/useAsync';

type Filter = 'all' | 'active' | 'ending' | 'expired' | 'none';

function EndsAt({ endsAt, state }: { endsAt: string | null; state: Filter }) {
  if (!endsAt) return <>—</>;
  if (state === 'expired') {
    const sameYear = tripoliDay(endsAt).slice(0, 4) === tripoliDay().slice(0, 4);
    return <span className="text-ink-3">انتهى {sameYear ? formatDayMonth(endsAt) : formatDate(endsAt)}</span>;
  }
  return <span className={state === 'ending' ? 'font-semibold text-warning-fg' : 'text-ink'}>{formatDate(endsAt)}</span>;
}

const LEGEND = [
  { title: 'مشترك', text: 'يظهر للزبائن ويستقبل الحجوزات من التطبيق.', icon: <Check size={20} />, tile: 'bg-success-bg text-success-fg' },
  { title: 'منتهي', text: 'حسابه موجود، يظهر كغير متاح للحجز حتى التجديد.', icon: <Clock size={20} />, tile: 'bg-warning-bg text-warning-fg' },
  { title: 'غير مشترك', text: 'أضافه الصالون أو الإدارة بالاسم فقط، بلا حساب في التطبيق.', icon: <User size={20} />, tile: 'bg-bg text-ink-2' },
];

export default function SalonPage() {
  const { id } = useParams<{ id: string }>();
  const { notify } = useToast();
  const [filter, setFilter] = useState<Filter>('all');
  const [extending, setExtending] = useState<AdminBarber | null>(null);
  const [adding, setAdding] = useState(false);
  const [name, setName] = useState('');
  const [removing, setRemoving] = useState<AdminBarber | null>(null);
  const [pausing, setPausing] = useState<AdminBarber | null>(null);

  const salon = useAsync(() => must<AdminSalon>(supabase().from('admin_salons').select('*').eq('id', id).single()), [id]);
  const barbers = useAsync(() => must<AdminBarber[]>(supabase().from('admin_barbers').select('*').eq('salon_id', id).neq('status', 'rejected').order('created_at', { ascending: true }).order('id')), [id]);

  const rows = useMemo(() => (barbers.data ?? []).filter((b) => filter === 'all' || barberSubscription(b) === filter), [barbers.data, filter]);
  const count = (state: Filter) => (barbers.data ?? []).filter((b) => barberSubscription(b) === state).length;

  function reload() {
    salon.reload();
    barbers.reload();
  }

  async function run(action: PromiseLike<{ error: unknown }>, success: string) {
    const { error } = await action;
    if (error) notify(errorMessage(error), 'error');
    else {
      notify(success);
      reload();
    }
  }

  async function addBarber() {
    await run(supabase().from('barbers').insert({ salon_id: id, display_name: name.trim(), status: 'active' }), 'تمت إضافة الحلاق');
    setAdding(false);
    setName('');
  }

  if (salon.error) return <ErrorNote message={salon.error} onRetry={salon.reload} />;
  if (!salon.data) return <Loading />;
  const s = salon.data;

  return (
    <>
      <nav aria-label="مسار التنقل" className="mb-4 flex items-center gap-2 text-[14px]">
        <Link href="/salons" className="font-semibold text-red-700 hover:underline">
          الصالونات
        </Link>
        <span className="text-ink-3">›</span>
        <span className="font-bold text-ink">{s.name}</span>
      </nav>

      <section className="flex flex-wrap items-center justify-between gap-6 rounded-card bg-blue-900 p-6 text-white">
        <div className="flex items-center gap-4">
          <span className="flex size-[72px] items-center justify-center rounded-ctl bg-blue-800 text-[32px] font-extrabold text-red-400">{Array.from(s.name)[0]}</span>
          <div>
            <h1 className="text-h1">{s.name}</h1>
            <p className="text-[14px] text-onDark">
              {s.area_name}، {s.city_name}
              {s.owner_name && <> · المالك: {s.owner_name}</>}
              {s.owner_phone && (
                <span className="whitespace-nowrap">
                  {' · '}
                  <span dir="ltr" className="inline-block">{formatPhone(s.owner_phone)}</span>
                </span>
              )}
            </p>
          </div>
        </div>
        <dl className="flex flex-wrap gap-3">
          {[
            ['كل الحلاقين', s.barbers_total],
            ['مشتركون', s.barbers_subscribed],
            ['حجوزات الشهر', s.bookings_month],
            ['التقييم', Number(s.rating_avg) > 0 ? Number(s.rating_avg).toFixed(1) : '—'],
          ].map(([label, value]) => (
            <div key={label} className="min-w-[110px] rounded-card bg-blue-800 p-3">
              <dt className="text-[13px] text-onDark">{label}</dt>
              <dd className="text-[28px] font-extrabold leading-9">{value}</dd>
            </div>
          ))}
        </dl>
      </section>

      <Card className="mt-6 flex flex-col gap-4">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h2 className="text-h2 text-ink">حلاقو الصالون</h2>
            <p className="text-caption text-ink-3">لكل حلاق اشتراكه الخاص. غير المشتركين يظهرون للزبائن في صفحة الصالون لكن لا يمكن الحجز معهم.</p>
          </div>
          <Button variant="accent" onClick={() => setAdding(true)}>
            <Plus size={18} /> إضافة حلاق للصالون
          </Button>
        </div>
        <Chips
          value={filter}
          onChange={setFilter}
          options={[
            { value: 'all', label: `الكل (${barbers.data?.length ?? 0})` },
            { value: 'active', label: `مشترك (${count('active') + count('ending')})` },
            { value: 'expired', label: `منتهي (${count('expired')})` },
            { value: 'none', label: `غير مشترك (${count('none')})` },
          ]}
        />
        {barbers.loading && !barbers.data ? (
          <Loading />
        ) : (
          <Table head={['الحلاق', 'الهاتف', 'حالة الاشتراك', 'ينتهي في', 'حجوزات الشهر', 'التقييم', 'الإجراء']} empty={rows.length === 0 && <Empty>لا يوجد حلاقون</Empty>}>
            {rows.map((b) => {
              const state = barberSubscription(b);
              const hasAccount = !!b.profile_id;
              return (
                <Row key={b.id} highlight={!hasAccount}>
                  <Cell>
                    <div className="flex items-center gap-3">
                      <Avatar name={b.display_name} muted={state === 'none' || state === 'expired'} />
                      <div>
                        <div className="font-bold text-ink">{b.display_name}</div>
                        <div className="text-caption text-ink-3">{b.is_salon_owner ? 'مالك الصالون' : hasAccount ? 'حلاق' : 'حلاق · بلا حساب'}</div>
                      </div>
                    </div>
                  </Cell>
                  <Cell>
                    <span dir="ltr" className="inline-block whitespace-nowrap">{formatPhone(b.phone)}</span>
                  </Cell>
                  <Cell>
                    <div className="flex flex-wrap gap-1">
                      {b.status === 'suspended' ? <BarberStatusBadge status="suspended" /> : b.status === 'pending' ? <BarberStatusBadge status="pending" /> : <SubscriptionBadge state={state} />}
                    </div>
                  </Cell>
                  <Cell className="whitespace-nowrap">
                    <EndsAt endsAt={b.subscription_ends_at} state={state} />
                  </Cell>
                  <Cell className="font-bold text-ink">{hasAccount ? b.bookings_month : '—'}</Cell>
                  <Cell>{b.rating_count > 0 ? Number(b.rating_avg).toFixed(1) : hasAccount ? 'جديد' : '—'}</Cell>
                  <Cell>
                    <div className="flex flex-wrap gap-2">
                      {hasAccount && b.status !== 'pending' && (
                        <Button size="sm" variant={state === 'expired' ? 'accent' : 'primary'} onClick={() => setExtending(b)}>
                          {state === 'expired' || state === 'none' ? 'تجديد' : 'تمديد'}
                        </Button>
                      )}
                      {b.status === 'active' && hasAccount && (
                        <Button size="sm" variant="danger" onClick={() => setPausing(b)}>
                          إيقاف
                        </Button>
                      )}
                      {b.status === 'suspended' && (
                        <Button size="sm" variant="secondary" onClick={() => run(supabase().rpc('reactivate_barber', { p_barber_id: b.id }), 'تمت إعادة التفعيل')}>
                          إعادة تفعيل
                        </Button>
                      )}
                      {state === 'expired' && b.phone && (
                        <a href={`tel:+${b.phone}`} aria-label={`اتصال بـ ${b.display_name}`} className="inline-flex h-9 items-center rounded-small border-[1.5px] border-line bg-white px-3 text-[14px] font-bold text-ink hover:border-blue-900">
                          اتصال
                        </a>
                      )}
                      {!hasAccount && (
                        <Button size="sm" variant="danger" onClick={() => setRemoving(b)}>
                          إزالة
                        </Button>
                      )}
                    </div>
                  </Cell>
                </Row>
              );
            })}
          </Table>
        )}
      </Card>

      <ul className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-3" aria-label="دليل حالات الاشتراك">
        {LEGEND.map((item) => (
          <li key={item.title} className="flex items-start gap-3 rounded-card border border-line bg-surface p-5">
            <span className={`flex size-10 shrink-0 items-center justify-center rounded-ctl ${item.tile}`}>{item.icon}</span>
            <div>
              <h3 className="text-[16px] font-bold text-ink">{item.title}</h3>
              <p className="text-caption text-ink-2">{item.text}</p>
            </div>
          </li>
        ))}
      </ul>

      {extending && <ActivateDialog barber={extending} onClose={() => setExtending(null)} onDone={reload} />}
      {pausing && (
        <ConfirmDialog title={`إيقاف ${pausing.display_name}؟`} confirmLabel="إيقاف الحلاق" danger onConfirm={() => run(supabase().rpc('suspend_barber', { p_barber_id: pausing.id }), 'تم إيقاف الحلاق')} onClose={() => setPausing(null)}>
          لن يظهر في البحث ولن يمكن الحجز معه حتى تعيد تفعيله.
        </ConfirmDialog>
      )}
      {removing && (
        <ConfirmDialog title={`إزالة ${removing.display_name}؟`} confirmLabel="إزالة" danger onConfirm={() => run(supabase().from('barbers').delete().eq('id', removing.id), 'تمت إزالة الحلاق')} onClose={() => setRemoving(null)}>
          سيُحذف الحلاق من الصالون.
        </ConfirmDialog>
      )}
      {adding && (
        <Modal title="إضافة حلاق للصالون" onClose={() => setAdding(false)}>
          <div className="flex flex-col gap-4">
            <p className="text-[14px] text-ink-3">يُضاف بالاسم فقط بلا حساب، ويظهر في صفحة الصالون كغير متاح للحجز.</p>
            <Field label="اسم الحلاق">{(fid) => <Input id={fid} value={name} onChange={(e) => setName(e.target.value)} maxLength={60} autoFocus />}</Field>
            <div className="flex gap-3">
              <Button size="lg" className="flex-1" disabled={!name.trim()} onClick={addBarber}>
                إضافة
              </Button>
              <Button variant="secondary" size="lg" onClick={() => setAdding(false)}>
                إلغاء
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </>
  );
}
