'use client';

import { Plus } from 'lucide-react';
import { useState } from 'react';

import { validAmount } from '@/components/ActivateDialog';
import { Badge, Button, Card, Cell, Empty, ErrorNote, Field, Input, Loading, Modal, PageHeader, Row, Select, Table, useToast } from '@/components/ui';
import { monthsText, planLabel, SUBSCRIPTION_AMOUNT_MAX, SUBSCRIPTION_MONTHS_MAX } from '@/lib/constants';
import { must } from '@/lib/db';
import { errorMessage } from '@/lib/errors';
import { formatDate, formatPrice } from '@/lib/format';
import { supabase } from '@/lib/supabase';
import type { SubscriptionPlan } from '@/lib/types';
import { useAsync } from '@/lib/useAsync';

type Draft = { months: number; price: string; isActive: boolean; existing: boolean };

async function savePlan(months: number, price: number, isActive: boolean) {
  return supabase().rpc('admin_save_subscription_plan', { p_months: months, p_price: price, p_is_active: isActive });
}

function PlanEditor({ draft, taken, onClose, onSaved }: { draft: Draft; taken: number[]; onClose: () => void; onSaved: () => void }) {
  const { notify } = useToast();
  const [months, setMonths] = useState(draft.months);
  const [price, setPrice] = useState(draft.price);
  const [isActive, setIsActive] = useState(draft.isActive);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const priceValid = validAmount(price) && Number(price) <= SUBSCRIPTION_AMOUNT_MAX;
  const choices = Array.from({ length: SUBSCRIPTION_MONTHS_MAX }, (_, i) => i + 1).filter((m) => draft.existing || !taken.includes(m));

  async function save() {
    setBusy(true);
    setError(null);
    const { error: rpcError } = await savePlan(months, Number(price), isActive);
    setBusy(false);
    if (rpcError) {
      setError(errorMessage(rpcError));
      return;
    }
    notify(`تم حفظ باقة ${planLabel(months)}`);
    onSaved();
    onClose();
  }

  return (
    <Modal title={draft.existing ? `تعديل باقة ${planLabel(draft.months)}` : 'إضافة باقة'} onClose={onClose}>
      <div className="flex flex-col gap-4">
        <Field label="المدة">
          {(id) => (
            <Select id={id} value={months} disabled={draft.existing} onChange={(e) => setMonths(Number(e.target.value))}>
              {choices.map((m) => (
                <option key={m} value={m}>
                  {monthsText(m)}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <Field label="السعر (د.ل)" error={price.trim() && !priceValid ? `السعر بين 0 و${SUBSCRIPTION_AMOUNT_MAX} د.ل` : null}>
          {(id) => <Input id={id} type="number" inputMode="decimal" min={0} max={SUBSCRIPTION_AMOUNT_MAX} step="0.5" value={price} invalid={!!price.trim() && !priceValid} onChange={(e) => setPrice(e.target.value)} />}
        </Field>
        <label className="flex items-center gap-3 text-[15px] font-semibold text-ink">
          <input type="checkbox" className="size-5 accent-blue-900" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
          متاحة عند تفعيل الاشتراكات
        </label>
        {error && <ErrorNote message={error} />}
        <div className="flex gap-3">
          <Button size="lg" className="flex-1" busy={busy} disabled={!priceValid || choices.length === 0} onClick={save}>
            حفظ الباقة
          </Button>
          <Button variant="secondary" size="lg" onClick={onClose}>
            إلغاء
          </Button>
        </div>
      </div>
    </Modal>
  );
}

export default function PlansPage() {
  const { notify } = useToast();
  const [editing, setEditing] = useState<Draft | null>(null);
  const plans = useAsync(() => must<SubscriptionPlan[]>(supabase().from('subscription_plans').select('id,months,price,is_active,updated_at').order('months')), []);
  const rows = plans.data ?? [];
  const taken = rows.map((p) => p.months);

  async function toggle(plan: SubscriptionPlan) {
    const { error } = await savePlan(plan.months, Number(plan.price), !plan.is_active);
    if (error) notify(errorMessage(error), 'error');
    else {
      notify(plan.is_active ? `أُوقفت باقة ${planLabel(plan.months)}` : `أُتيحت باقة ${planLabel(plan.months)}`);
      plans.reload();
    }
  }

  return (
    <>
      <PageHeader
        title="الباقات"
        subtitle="يُعبّأ المبلغ في نافذة التفعيل من سعر الباقة، وأي مبلغ مختلف يحتاج سبباً"
        actions={
          <Button variant="accent" disabled={taken.length >= SUBSCRIPTION_MONTHS_MAX} onClick={() => setEditing({ months: Array.from({ length: SUBSCRIPTION_MONTHS_MAX }, (_, i) => i + 1).find((m) => !taken.includes(m)) ?? 1, price: '', isActive: true, existing: false })}>
            <Plus size={18} /> إضافة باقة
          </Button>
        }
      />
      <Card>
        {plans.loading && !plans.data ? (
          <Loading />
        ) : plans.error ? (
          <ErrorNote message={plans.error} onRetry={plans.reload} />
        ) : (
          <Table head={['الباقة', 'المدة', 'السعر', 'الحالة', 'آخر تعديل', 'الإجراء']} empty={rows.length === 0 && <Empty>لا توجد باقات</Empty>}>
            {rows.map((plan) => (
              <Row key={plan.id} highlight={!plan.is_active}>
                <Cell className="font-bold text-ink">{planLabel(plan.months)}</Cell>
                <Cell>{monthsText(plan.months)}</Cell>
                <Cell className="whitespace-nowrap font-bold text-red-700">{formatPrice(plan.price)}</Cell>
                <Cell>{plan.is_active ? <Badge tone="success">متاحة</Badge> : <Badge tone="neutral">موقوفة</Badge>}</Cell>
                <Cell className="whitespace-nowrap">{formatDate(plan.updated_at)}</Cell>
                <Cell>
                  <div className="flex flex-wrap gap-2">
                    <Button size="sm" onClick={() => setEditing({ months: plan.months, price: String(Number(plan.price)), isActive: plan.is_active, existing: true })}>
                      تعديل
                    </Button>
                    <Button size="sm" variant={plan.is_active ? 'danger' : 'secondary'} onClick={() => toggle(plan)}>
                      {plan.is_active ? 'إيقاف' : 'إتاحة'}
                    </Button>
                  </div>
                </Cell>
              </Row>
            ))}
          </Table>
        )}
      </Card>
      {editing && <PlanEditor draft={editing} taken={taken} onClose={() => setEditing(null)} onSaved={plans.reload} />}
    </>
  );
}
