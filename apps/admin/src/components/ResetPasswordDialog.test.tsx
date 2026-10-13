import { FunctionsFetchError, FunctionsHttpError } from '@supabase/supabase-js';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { fakeSupabase, type FakeSupabase } from '@/test/fakeSupabase';

import { ResetPasswordDialog } from './ResetPasswordDialog';

let fake: FakeSupabase;
vi.mock('@/lib/supabase', () => ({ supabase: () => fake.client }));

const TARGET = { profile_id: '10000000-0000-0000-0000-000000000004', name: 'خالد المقريف', phone: '218911002030' };

function renderDialog() {
  const onClose = vi.fn();
  render(<ResetPasswordDialog target={TARGET} onClose={onClose} />);
  return { onClose, user: userEvent.setup() };
}

const reset = () => screen.getByRole('button', { name: 'إنشاء كلمة مرور مؤقتة' });

beforeEach(() => {
  fake = fakeSupabase();
});

describe('ResetPasswordDialog', () => {
  it('calls the Edge Function through functions.invoke and shows the password once', async () => {
    fake.invoke.mockResolvedValueOnce({ data: { temporary_password: 'r999DtS7PB8q' }, error: null });
    const { user } = renderDialog();
    expect(screen.getByText('+218 91 100 2030')).toBeInTheDocument();
    await user.click(reset());

    expect(fake.invoke).toHaveBeenCalledWith('admin-reset-password', { body: { profile_id: TARGET.profile_id } });
    expect(await screen.findByTestId('temporary-password')).toHaveTextContent('r999DtS7PB8q');
    expect(screen.getByText(/سيُطلب منه اختيار كلمة مرور جديدة عند الدخول/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'إنشاء كلمة مرور مؤقتة' })).not.toBeInTheDocument();
  });

  it('cannot be dismissed with Escape while the password is on screen', async () => {
    fake.invoke.mockResolvedValueOnce({ data: { temporary_password: 'r999DtS7PB8q' }, error: null });
    const { user, onClose } = renderDialog();
    await user.click(reset());
    await screen.findByTestId('temporary-password');
    await user.keyboard('{Escape}');
    expect(onClose).not.toHaveBeenCalled();
  });

  it.each([
    ['role_not_resettable', 403, 'لا يمكن إعادة تعيين كلمة مرور هذا الحساب'],
    ['admin_only', 403, 'هذا الإجراء للإدارة فقط'],
    ['password_update_failed', 502, 'تعذّر تغيير كلمة المرور، أعد المحاولة'],
    ['session_revoke_failed', 502, 'تغيّرت كلمة المرور لكن تعذّر إنهاء جلسات الحساب، أعد المحاولة'],
  ])('maps the function error %s to Arabic', async (code, status, message) => {
    const response = new Response(JSON.stringify({ error: code }), { status, headers: { 'Content-Type': 'application/json' } });
    fake.invoke.mockResolvedValueOnce({ data: null, error: new FunctionsHttpError(response) });
    const { user } = renderDialog();
    await user.click(reset());
    expect(await screen.findByRole('alert')).toHaveTextContent(message);
    expect(screen.queryByTestId('temporary-password')).not.toBeInTheDocument();
    expect(reset()).toBeEnabled();
  });

  it('a network or CORS failure gets its own message that points at ADMIN_ALLOWED_ORIGINS', async () => {
    fake.invoke.mockResolvedValueOnce({ data: null, error: new FunctionsFetchError(new TypeError('Failed to fetch')) });
    const { user } = renderDialog();
    await user.click(reset());
    expect(await screen.findByRole('alert')).toHaveTextContent('تعذّر الوصول إلى خدمة إعادة التعيين. تحقّق من الاتصال، أو من إعداد ADMIN_ALLOWED_ORIGINS على الخادم.');
  });
});
