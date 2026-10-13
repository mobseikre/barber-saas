import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { fakeSupabase, type FakeSupabase } from '@/test/fakeSupabase';
import { PLANS } from '@/test/plans';

import { ActivateDialog, endsAfter, type SubscriptionTarget } from './ActivateDialog';
import { ToastProvider } from './ui';

let fake: FakeSupabase;
vi.mock('@/lib/supabase', () => ({ supabase: () => fake.client }));

const BARBER: SubscriptionTarget = { id: 'barber-1', display_name: 'علي القماطي', subscription_ends_at: null };

function renderDialog(barber = BARBER) {
  const onDone = vi.fn();
  const onClose = vi.fn();
  render(
    <ToastProvider>
      <ActivateDialog barber={barber} onClose={onClose} onDone={onDone} />
    </ToastProvider>,
  );
  return { onDone, onClose, user: userEvent.setup() };
}

const amount = () => screen.getByLabelText('المبلغ المدفوع نقداً (د.ل)') as HTMLInputElement;
const confirm = () => screen.getByRole('button', { name: 'تأكيد استلام المبلغ وتفعيل الاشتراك' });

beforeEach(() => {
  fake = fakeSupabase({ subscription_plans: PLANS });
});

describe('ActivateDialog', () => {
  it('prefills the amount from the plan and keeps it locked', async () => {
    const { user } = renderDialog();
    await waitFor(() => expect(amount()).toHaveValue(50));
    expect(amount()).toHaveAttribute('readonly');
    expect(screen.queryByLabelText('سبب تعديل المبلغ')).not.toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText('الباقة'), '3');
    expect(amount()).toHaveValue(150);
    expect(amount()).toHaveAttribute('readonly');
    expect(confirm()).toBeEnabled();
  });

  it('only offers active plans, read from subscription_plans', async () => {
    renderDialog();
    await waitFor(() => expect(screen.getAllByRole('option')).toHaveLength(4));
    const query = fake.queries.find((q) => q.table === 'subscription_plans')!;
    expect(query.calls).toContainEqual(['eq', ['is_active', true]]);
    expect(screen.getByRole('option', { name: 'ربع سنوي (3 أشهر) · 150 د.ل' })).toBeInTheDocument();
  });

  it('activates at the plan price without an override reason', async () => {
    const { user, onDone, onClose } = renderDialog();
    await waitFor(() => expect(amount()).toHaveValue(50));
    await user.selectOptions(screen.getByLabelText('الباقة'), '12');
    await user.type(screen.getByLabelText('ملاحظة (اختياري)'), 'نقداً');
    await user.click(confirm());

    expect(fake.rpc).toHaveBeenCalledWith('activate_subscription', {
      p_barber_id: 'barber-1',
      p_months: 12,
      p_amount: 500,
      p_note: 'اشتراك سنوي — نقداً',
      p_override_reason: null,
    });
    await waitFor(() => expect(onDone).toHaveBeenCalled());
    expect(onClose).toHaveBeenCalled();
  });

  it('"تعديل المبلغ" unlocks the amount and requires a reason that is sent with it', async () => {
    const { user } = renderDialog();
    await waitFor(() => expect(amount()).toHaveValue(50));
    await user.click(screen.getByRole('button', { name: 'تعديل المبلغ' }));
    expect(amount()).not.toHaveAttribute('readonly');
    await user.clear(amount());
    await user.type(amount(), '40');
    expect(confirm()).toBeDisabled();
    expect(screen.getByText('مطلوب. سعر الباقة 50 د.ل')).toBeInTheDocument();

    await user.type(screen.getByLabelText('سبب تعديل المبلغ'), '  خصم الشهر الأول ');
    expect(confirm()).toBeEnabled();
    await user.click(confirm());
    expect(fake.rpc).toHaveBeenCalledWith('activate_subscription', expect.objectContaining({ p_amount: 40, p_override_reason: 'خصم الشهر الأول' }));
  });

  it('changing the plan goes back to its price and locks the amount again', async () => {
    const { user } = renderDialog();
    await waitFor(() => expect(amount()).toHaveValue(50));
    await user.click(screen.getByRole('button', { name: 'تعديل المبلغ' }));
    await user.clear(amount());
    await user.type(amount(), '10');
    await user.selectOptions(screen.getByLabelText('الباقة'), '6');
    expect(amount()).toHaveValue(280);
    expect(amount()).toHaveAttribute('readonly');
    expect(screen.queryByLabelText('سبب تعديل المبلغ')).not.toBeInTheDocument();
  });

  it.each([
    ['override_reason_required', 'المبلغ يختلف عن سعر الباقة، اكتب سبب التعديل'],
    ['plan_not_found', 'هذه الباقة غير متاحة، حدّث الصفحة واختر باقة أخرى'],
    ['invalid_months', 'مدة الباقة يجب أن تكون بين 1 و24 شهراً'],
    ['invalid_amount', 'المبلغ يجب أن يكون بين 0 و10000 د.ل'],
  ])('shows %s in Arabic and keeps the dialog open', async (code, message) => {
    fake.rpc.mockResolvedValueOnce({ data: null, error: { message: code, code: 'P0001' } });
    const { user, onDone } = renderDialog();
    await waitFor(() => expect(amount()).toHaveValue(50));
    await user.click(confirm());
    expect(await screen.findByRole('alert')).toHaveTextContent(message);
    expect(onDone).not.toHaveBeenCalled();
  });

  it('says there are no active plans instead of showing an empty form', async () => {
    fake.tables.subscription_plans = [];
    renderDialog();
    expect(await screen.findByText('لا توجد باقات مفعّلة. أضف باقة من صفحة الباقات.')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'تأكيد استلام المبلغ وتفعيل الاشتراك' })).not.toBeInTheDocument();
  });

  it('previews the end date clamped to the last day of the month', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-01-31T10:00:00Z'));
    renderDialog();
    expect(await screen.findByTestId('ends-at')).toHaveTextContent('28 فبراير 2026');
  });

  it('extends from the current end date when the subscription is still running', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-10-13T10:00:00Z'));
    const { user } = renderDialog({ ...BARBER, subscription_ends_at: '2027-03-31T10:00:00Z' });
    expect(await screen.findByRole('dialog', { name: 'تمديد اشتراك علي القماطي' })).toBeInTheDocument();
    await waitFor(() => expect(amount()).toHaveValue(50));
    expect(screen.getByTestId('ends-at')).toHaveTextContent('30 أبريل 2027');
    await user.selectOptions(screen.getByLabelText('الباقة'), '3');
    expect(screen.getByTestId('ends-at')).toHaveTextContent('30 يونيو 2027');
  });
});

describe('endsAfter', () => {
  it.each([
    ['2026-01-31T10:00:00Z', 1, '28 فبراير 2026'],
    ['2028-01-31T10:00:00Z', 1, '29 فبراير 2028'],
    ['2026-08-31T10:00:00Z', 1, '30 سبتمبر 2026'],
    ['2026-03-31T10:00:00Z', 3, '30 يونيو 2026'],
    ['2026-10-15T10:00:00Z', 12, '15 أكتوبر 2027'],
  ])('from %s plus %i month(s) is %s', (from, months, expected) => {
    expect(endsAfter(null, months, new Date(from))).toBe(expected);
  });
});
