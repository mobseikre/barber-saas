'use client';

import { useState } from 'react';

import { ActivateDialog } from '@/components/ActivateDialog';
import { ExpiringList } from '@/components/ExpiringList';
import { Button, Card, Cell, Empty, ErrorNote, Field, Loading, Modal, PageHeader, Row, Select, Table } from '@/components/ui';
import { EXPIRING_SOON_DAYS, PAGE_SIZE } from '@/lib/constants';
import { must } from '@/lib/db';
import { formatDate, formatPrice } from '@/lib/format';
import { supabase } from '@/lib/supabase';
import type { AdminBarber, SubscriptionPayment } from '@/lib/types';
import { useAsync } from '@/lib/useAsync';

function PickBarber({ onPick, onClose }: { onPick: (barber: AdminBarber) => void; onClose: () => void }) {
  const [selected, setSelected] = useState('');
  const list = useAsync(
    () => must<AdminBarber[]>(supabase().from('admin_barbers').select('*').not('profile_id', 'is', null).neq('status', 'rejected').order('display_name')),
    [],
  );

  return (
    <Modal title="تفعيل اشتراك لحلاق" onClose={onClose}>
      <div className="flex flex-col gap-4">
        {list.error ? (
          <ErrorNote message={list.error} onRetry={list.reload} />
        ) : (
          <Field label="الحلاق">
            {(id) => (
              <Select id={id} value={selected} onChange={(e) => setSelected(e.target.value)}>
                <option value="">اختر الحلاق</option>
                {(list.data ?? []).map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.display_name} — {b.salon_name}
                  </option>
                ))}
              </Select>
            )}
          </Field>
        )}
        <Button size="lg" disabled={!selected} onClick={() => onPick(list.data!.find((b) => b.id === selected)!)}>
          متابعة
        </Button>
      </div>
    </Modal>
  );
}

export default function SubscriptionsPage() {
  const [picking, setPicking] = useState(false);
  const [target, setTarget] = useState<AdminBarber | null>(null);
  const [limit, setLimit] = useState(PAGE_SIZE);

  const payments = useAsync(
    () => must<SubscriptionPayment[]>(supabase().from('admin_subscription_payments').select('*').order('paid_at', { ascending: false }).limit(limit + 1)),
    [limit],
  );
  const rows = (payments.data ?? []).slice(0, limit);

  return (
    <>
      <PageHeader
        title="الاشتراكات"
        subtitle="الدفع نقداً في الصالون، وتفعّل الإدارة الاشتراك يدوياً"
        actions={
          <Button variant="accent" onClick={() => setPicking(true)}>
            تفعيل اشتراك
          </Button>
        }
      />
      <div className="grid grid-cols-1 items-start gap-6 2xl:grid-cols-[minmax(0,1fr)_minmax(0,1.6fr)]">
        <Card>
          <h2 className="text-h2 text-ink">تنتهي خلال {EXPIRING_SOON_DAYS} أيام</h2>
          <p className="mb-2 text-caption text-ink-3">اتصل بالحلاق ثم جدّد اشتراكه بعد استلام المبلغ</p>
          <ExpiringList days={EXPIRING_SOON_DAYS} onChanged={payments.reload} />
        </Card>
        <Card>
          <h2 className="mb-4 text-h2 text-ink">سجل المدفوعات</h2>
          {payments.loading && !payments.data ? (
            <Loading />
          ) : payments.error ? (
            <ErrorNote message={payments.error} onRetry={payments.reload} />
          ) : (
            <>
              <Table head={['التاريخ', 'الحلاق', 'المبلغ', 'ينتهي في', 'سجّلها', 'ملاحظة']} empty={rows.length === 0 && <Empty>لا توجد مدفوعات بعد</Empty>}>
                {rows.map((p) => (
                  <Row key={p.id}>
                    <Cell className="whitespace-nowrap">{formatDate(p.paid_at)}</Cell>
                    <Cell className="font-bold text-ink">{p.barber_name}</Cell>
                    <Cell className="whitespace-nowrap">
                      <div className="font-bold text-red-700">{formatPrice(p.amount)}</div>
                      {p.override_reason && p.plan_price != null && <div className="text-caption text-ink-3">سعر الباقة {formatPrice(p.plan_price)}</div>}
                    </Cell>
                    <Cell className="whitespace-nowrap">{formatDate(p.period_end)}</Cell>
                    <Cell>{p.recorded_by_name ?? '—'}</Cell>
                    <Cell>
                      {p.note ?? (p.override_reason ? null : '—')}
                      {p.override_reason && <div className="text-caption text-warning-fg">سبب التعديل: {p.override_reason}</div>}
                    </Cell>
                  </Row>
                ))}
              </Table>
              {(payments.data ?? []).length > limit && (
                <div className="mt-4 flex justify-center">
                  <Button variant="secondary" onClick={() => setLimit((n) => n + PAGE_SIZE)}>
                    عرض المزيد
                  </Button>
                </div>
              )}
            </>
          )}
        </Card>
      </div>
      {picking && (
        <PickBarber
          onClose={() => setPicking(false)}
          onPick={(barber) => {
            setPicking(false);
            setTarget(barber);
          }}
        />
      )}
      {target && <ActivateDialog barber={target} onClose={() => setTarget(null)} onDone={payments.reload} />}
    </>
  );
}
