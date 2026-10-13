import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { AdminBarber } from '@/lib/types';
import { fakeSupabase, type FakeSupabase } from '@/test/fakeSupabase';
import { PLANS } from '@/test/plans';

import { ApproveDialog } from './ApproveDialog';
import { ToastProvider } from './ui';

let fake: FakeSupabase;
vi.mock('@/lib/supabase', () => ({ supabase: () => fake.client }));
vi.mock('./LocationPicker', () => ({
  LocationPicker: ({ onChange }: { onChange: (lat: number, lng: number) => void }) => (
    <button type="button" onClick={() => onChange(32.9, 13.2)}>
      تحريك الدبوس
    </button>
  ),
}));

const BARBER: AdminBarber = {
  id: 'barber-1',
  display_name: 'علي القماطي',
  status: 'pending',
  is_vip: false,
  subscription_ends_at: null,
  created_at: '2026-10-10T10:00:00Z',
  rating_avg: 0,
  rating_count: 0,
  profile_id: 'profile-1',
  phone: '218912345678',
  salon_id: 'salon-1',
  salon_name: 'صالون الأناقة',
  address: 'شارع الجمهورية',
  is_salon_owner: true,
  area_id: 'area-1',
  area_name: 'حي الأندلس',
  city_id: 'city-1',
  city_name: 'طرابلس',
  latitude: 32.8752,
  longitude: 13.1146,
  is_bookable: false,
  bookings_month: 0,
};

function renderDialog() {
  const onDone = vi.fn();
  render(
    <ToastProvider>
      <ApproveDialog barber={BARBER} onClose={vi.fn()} onDone={onDone} />
    </ToastProvider>,
  );
  return { onDone, user: userEvent.setup() };
}

const amount = () => screen.getByLabelText('المبلغ المدفوع نقداً (د.ل)') as HTMLInputElement;

beforeEach(() => {
  fake = fakeSupabase({ subscription_plans: PLANS });
});

describe('ApproveDialog', () => {
  it('activates with the plan price, locked, in one step', async () => {
    const { user, onDone } = renderDialog();
    await waitFor(() => expect(amount()).toHaveValue(50));
    expect(amount()).toHaveAttribute('readonly');
    await user.selectOptions(screen.getByLabelText('الباقة'), '3');
    await user.click(screen.getByRole('button', { name: 'تفعيل وتحديد الباقة' }));

    expect(fake.rpc).toHaveBeenCalledTimes(1);
    expect(fake.rpc).toHaveBeenCalledWith('activate_subscription', {
      p_barber_id: 'barber-1',
      p_months: 3,
      p_amount: 150,
      p_note: 'اشتراك ربع سنوي',
      p_override_reason: null,
    });
    await waitFor(() => expect(onDone).toHaveBeenCalled());
  });

  it('a changed amount needs a reason before the barber can be approved', async () => {
    const { user } = renderDialog();
    await waitFor(() => expect(amount()).toHaveValue(50));
    const approve = screen.getByRole('button', { name: 'تفعيل وتحديد الباقة' });
    await user.click(screen.getByRole('button', { name: 'تعديل المبلغ' }));
    await user.clear(amount());
    await user.type(amount(), '0');
    expect(approve).toBeDisabled();
    await user.type(screen.getByLabelText('سبب تعديل المبلغ'), 'شهر مجاني للافتتاح');
    await user.click(approve);
    expect(fake.rpc).toHaveBeenCalledWith('activate_subscription', expect.objectContaining({ p_amount: 0, p_override_reason: 'شهر مجاني للافتتاح' }));
  });

  it('saves a moved pin before activating', async () => {
    const { user } = renderDialog();
    await waitFor(() => expect(amount()).toHaveValue(50));
    await user.click(screen.getByRole('button', { name: 'تحريك الدبوس' }));
    await user.click(screen.getByRole('button', { name: 'تفعيل وتحديد الباقة' }));
    expect(fake.rpc.mock.calls.map(([name]) => name)).toEqual(['admin_set_salon_location', 'activate_subscription']);
  });

  it('approves without a subscription when the plan is unticked', async () => {
    const { user } = renderDialog();
    await user.click(screen.getByRole('checkbox'));
    expect(screen.queryByLabelText('الباقة')).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'اعتماد بدون اشتراك' }));
    expect(fake.rpc).toHaveBeenCalledWith('approve_barber', { p_barber_id: 'barber-1' });
  });

  it('shows the server error in Arabic', async () => {
    fake.rpc.mockResolvedValueOnce({ data: null, error: { message: 'plan_not_found', code: 'P0001' } });
    const { user, onDone } = renderDialog();
    await waitFor(() => expect(amount()).toHaveValue(50));
    await user.click(screen.getByRole('button', { name: 'تفعيل وتحديد الباقة' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('هذه الباقة غير متاحة، حدّث الصفحة واختر باقة أخرى');
    expect(onDone).not.toHaveBeenCalled();
  });
});
