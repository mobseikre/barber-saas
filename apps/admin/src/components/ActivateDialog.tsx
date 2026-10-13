'use client';

import { useEffect, useState, type ReactNode } from 'react';

import { monthsText, NOTE_MAX_LENGTH, planLabel } from '@/lib/constants';
import { must } from '@/lib/db';
import { errorMessage } from '@/lib/errors';
import { addMonths, formatDate, formatPrice } from '@/lib/format';
import { supabase } from '@/lib/supabase';
import type { SubscriptionPlan } from '@/lib/types';
import { useAsync } from '@/lib/useAsync';

import { Button, Empty, ErrorNote, Field, Input, Loading, Modal, Select, useToast } from './ui';

export interface SubscriptionTarget {
  id: string;
  display_name: string;
  subscription_ends_at: string | null;
}

export function planNote(months: number, note: string): string {
  return [`اشتراك ${planLabel(months)}`, note.trim() || null].filter(Boolean).join(' — ');
}

export function planOptionLabel(plan: SubscriptionPlan): string {
  const label = planLabel(plan.months);
  const duration = monthsText(plan.months);
  return `${label === duration ? label : `${label} (${duration})`} · ${formatPrice(plan.price)}`;
}

export const validAmount = (amount: string) => amount.trim() !== '' && Number.isFinite(Number(amount)) && Number(amount) >= 0;

export function endsAfter(current: string | null, months: number, now = new Date()): string {
  const start = new Date(Math.max(now.getTime(), current ? new Date(current).getTime() : 0));
  return formatDate(addMonths(start, months));
}

export function useActivePlans() {
  return useAsync(
    () => must<SubscriptionPlan[]>(supabase().from('subscription_plans').select('id,months,price,is_active,updated_at').eq('is_active', true).order('months')),
    [],
  );
}

export interface PlanForm {
  plans: SubscriptionPlan[];
  plan: SubscriptionPlan | undefined;
  months: number;
  selectMonths: (months: number) => void;
  amount: string;
  setAmount: (value: string) => void;
  editing: boolean;
  startEditing: () => void;
  reason: string;
  setReason: (value: string) => void;
  note: string;
  setNote: (value: string) => void;
  ready: boolean;
  args: (barberId: string) => Record<string, unknown>;
}

export function usePlanForm(plans: SubscriptionPlan[] | undefined): PlanForm {
  const list = plans ?? [];
  const [months, setMonths] = useState<number | null>(null);
  const [amount, setAmount] = useState('');
  const [editing, setEditing] = useState(false);
  const [reason, setReason] = useState('');
  const [note, setNote] = useState('');

  const chosen = months ?? list[0]?.months ?? 0;
  const plan = list.find((p) => p.months === chosen);

  useEffect(() => {
    const first = plans?.[0];
    if (months == null && first) {
      setMonths(first.months);
      setAmount(String(Number(first.price)));
    }
  }, [months, plans]);

  function selectMonths(value: number) {
    const next = list.find((p) => p.months === value);
    setMonths(value);
    setAmount(next ? String(Number(next.price)) : '');
    setEditing(false);
    setReason('');
  }

  return {
    plans: list,
    plan,
    months: chosen,
    selectMonths,
    amount,
    setAmount,
    editing,
    startEditing: () => setEditing(true),
    reason,
    setReason,
    note,
    setNote,
    ready: !!plan && validAmount(amount) && (!editing || reason.trim() !== ''),
    args: (barberId) => ({
      p_barber_id: barberId,
      p_months: chosen,
      p_amount: Number(amount),
      p_note: planNote(chosen, note) || null,
      p_override_reason: editing ? reason.trim() : null,
    }),
  };
}

export function PlanFields({ form }: { form: PlanForm }) {
  return (
    <>
      <Field label="الباقة">
        {(id) => (
          <Select id={id} value={form.months} onChange={(e) => form.selectMonths(Number(e.target.value))}>
            {form.plans.map((plan) => (
              <option key={plan.id} value={plan.months}>
                {planOptionLabel(plan)}
              </option>
            ))}
          </Select>
        )}
      </Field>
      <div className="flex flex-col gap-1.5">
        <Field label="المبلغ المدفوع نقداً (د.ل)">
          {(id) => (
            <Input
              id={id}
              type="number"
              inputMode="decimal"
              min={0}
              step="0.5"
              value={form.amount}
              readOnly={!form.editing}
              aria-readonly={!form.editing}
              className={form.editing ? undefined : 'cursor-default !bg-blue-100 !text-ink-2'}
              onChange={(e) => form.setAmount(e.target.value)}
            />
          )}
        </Field>
        {!form.editing && (
          <Button variant="link" className="self-start" onClick={form.startEditing}>
            تعديل المبلغ
          </Button>
        )}
      </div>
      {form.editing && (
        <Field label="سبب تعديل المبلغ" error={form.reason.trim() ? null : `مطلوب. سعر الباقة ${form.plan ? formatPrice(form.plan.price) : ''}`}>
          {(id) => <Input id={id} value={form.reason} onChange={(e) => form.setReason(e.target.value)} maxLength={NOTE_MAX_LENGTH} invalid={!form.reason.trim()} autoFocus />}
        </Field>
      )}
      <Field label="ملاحظة (اختياري)">{(id) => <Input id={id} value={form.note} onChange={(e) => form.setNote(e.target.value)} maxLength={NOTE_MAX_LENGTH} />}</Field>
    </>
  );
}

export function PlansState({ plans, children }: { plans: ReturnType<typeof useActivePlans>; children: ReactNode }) {
  if (plans.error) return <ErrorNote message={plans.error} onRetry={plans.reload} />;
  if (!plans.data) return <Loading />;
  if (plans.data.length === 0) return <Empty>لا توجد باقات مفعّلة. أضف باقة من صفحة الباقات.</Empty>;
  return <>{children}</>;
}

export function ActivateDialog({ barber, onClose, onDone }: { barber: SubscriptionTarget; onClose: () => void; onDone: () => void }) {
  const { notify } = useToast();
  const plans = useActivePlans();
  const form = usePlanForm(plans.data);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const extending = !!barber.subscription_ends_at && new Date(barber.subscription_ends_at) > new Date();

  async function submit() {
    setBusy(true);
    setError(null);
    const { error: rpcError } = await supabase().rpc('activate_subscription', form.args(barber.id));
    setBusy(false);
    if (rpcError) {
      setError(errorMessage(rpcError));
      return;
    }
    notify(extending ? `تم تمديد اشتراك ${barber.display_name}` : `تم تفعيل اشتراك ${barber.display_name}`);
    onDone();
    onClose();
  }

  return (
    <Modal title={extending ? `تمديد اشتراك ${barber.display_name}` : `تفعيل اشتراك ${barber.display_name}`} onClose={onClose}>
      <PlansState plans={plans}>
        <div className="flex flex-col gap-4">
          <PlanFields form={form} />
          <p className="text-caption text-ink-3">
            {extending ? 'يمتد الاشتراك الحالي حتى ' : 'ينتهي الاشتراك في '}
            <strong className="text-ink" data-testid="ends-at">
              {endsAfter(barber.subscription_ends_at, form.months)}
            </strong>
          </p>
          {error && <ErrorNote message={error} />}
          <div className="flex gap-3">
            <Button size="lg" className="flex-1" busy={busy} disabled={!form.ready} onClick={submit}>
              تأكيد استلام المبلغ وتفعيل الاشتراك
            </Button>
            <Button variant="secondary" size="lg" onClick={onClose}>
              إلغاء
            </Button>
          </div>
        </div>
      </PlansState>
    </Modal>
  );
}
