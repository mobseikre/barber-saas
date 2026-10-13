import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { ToastProvider } from '@/components/ui';
import { fakeSupabase, type FakeSupabase } from '@/test/fakeSupabase';
import { PLANS, planWith } from '@/test/plans';

import PlansPage from './page';

let fake: FakeSupabase;
vi.mock('@/lib/supabase', () => ({ supabase: () => fake.client }));

function renderPage() {
  render(
    <ToastProvider>
      <PlansPage />
    </ToastProvider>,
  );
  return userEvent.setup();
}

const row = (name: string) => screen.getAllByRole('row').find((r) => within(r).queryAllByRole('cell')[0]?.textContent === name)!;

beforeEach(() => {
  fake = fakeSupabase({ subscription_plans: [...PLANS.slice(0, 3), planWith(12, 500, false)] });
});

describe('PlansPage', () => {
  it('lists every plan, inactive ones included, with price and state', async () => {
    renderPage();
    await screen.findByText('ربع سنوي');
    expect(within(row('شهري')).getByText('50 د.ل')).toBeInTheDocument();
    expect(within(row('شهري')).getByText('متاحة')).toBeInTheDocument();
    expect(within(row('سنوي')).getByText('موقوفة')).toBeInTheDocument();
    expect(within(row('سنوي')).getByRole('button', { name: 'إتاحة' })).toBeInTheDocument();
    const query = fake.queries.find((q) => q.table === 'subscription_plans')!;
    expect(query.calls.some(([method]) => method === 'eq')).toBe(false);
  });

  it('edits a price through admin_save_subscription_plan', async () => {
    const user = renderPage();
    await screen.findByText('ربع سنوي');
    await user.click(within(row('ربع سنوي')).getByRole('button', { name: 'تعديل' }));
    const dialog = screen.getByRole('dialog', { name: 'تعديل باقة ربع سنوي' });
    expect(within(dialog).getByLabelText('المدة')).toBeDisabled();
    const price = within(dialog).getByLabelText('السعر (د.ل)');
    expect(price).toHaveValue(150);
    await user.clear(price);
    await user.type(price, '160');
    await user.click(within(dialog).getByRole('button', { name: 'حفظ الباقة' }));

    expect(fake.rpc).toHaveBeenCalledWith('admin_save_subscription_plan', { p_months: 3, p_price: 160, p_is_active: true });
    expect(await screen.findByRole('status')).toHaveTextContent('تم حفظ باقة ربع سنوي');
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
  });

  it('pauses and re-offers plans in one click', async () => {
    const user = renderPage();
    await screen.findByText('ربع سنوي');
    await user.click(within(row('شهري')).getByRole('button', { name: 'إيقاف' }));
    expect(fake.rpc).toHaveBeenLastCalledWith('admin_save_subscription_plan', { p_months: 1, p_price: 50, p_is_active: false });
    await user.click(within(row('سنوي')).getByRole('button', { name: 'إتاحة' }));
    expect(fake.rpc).toHaveBeenLastCalledWith('admin_save_subscription_plan', { p_months: 12, p_price: 500, p_is_active: true });
  });

  it('adds a plan for a duration that has none yet', async () => {
    const user = renderPage();
    await screen.findByText('ربع سنوي');
    await user.click(screen.getByRole('button', { name: 'إضافة باقة' }));
    const dialog = screen.getByRole('dialog', { name: 'إضافة باقة' });
    const months = within(dialog).getByLabelText('المدة');
    const offered = within(months).getAllByRole('option').map((o) => Number((o as HTMLOptionElement).value));
    expect(offered).not.toContain(1);
    expect(offered).not.toContain(12);
    expect(offered).toHaveLength(20);
    expect(Math.max(...offered)).toBe(24);

    const save = within(dialog).getByRole('button', { name: 'حفظ الباقة' });
    expect(save).toBeDisabled();
    await user.selectOptions(months, '2');
    await user.type(within(dialog).getByLabelText('السعر (د.ل)'), '95');
    await user.click(save);
    expect(fake.rpc).toHaveBeenCalledWith('admin_save_subscription_plan', { p_months: 2, p_price: 95, p_is_active: true });
  });

  it('refuses a price above the cap before calling the server', async () => {
    const user = renderPage();
    await screen.findByText('ربع سنوي');
    await user.click(within(row('شهري')).getByRole('button', { name: 'تعديل' }));
    const dialog = screen.getByRole('dialog');
    const price = within(dialog).getByLabelText('السعر (د.ل)');
    await user.clear(price);
    await user.type(price, '10001');
    expect(within(dialog).getByText('السعر بين 0 و10000 د.ل')).toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: 'حفظ الباقة' })).toBeDisabled();
    expect(fake.rpc).not.toHaveBeenCalled();
  });

  it('shows a server refusal in Arabic inside the dialog', async () => {
    fake.rpc.mockResolvedValueOnce({ data: null, error: { message: 'invalid_amount', code: 'P0001' } });
    const user = renderPage();
    await screen.findByText('ربع سنوي');
    await user.click(within(row('شهري')).getByRole('button', { name: 'تعديل' }));
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'حفظ الباقة' }));
    expect(await within(screen.getByRole('dialog')).findByRole('alert')).toHaveTextContent('المبلغ يجب أن يكون بين 0 و10000 د.ل');
  });
});
