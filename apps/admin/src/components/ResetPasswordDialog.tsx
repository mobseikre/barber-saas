'use client';

import { FunctionsHttpError } from '@supabase/supabase-js';
import { Check, Copy } from 'lucide-react';
import { useState } from 'react';

import { errorMessage } from '@/lib/errors';
import { formatPhone } from '@/lib/phone';
import { supabase } from '@/lib/supabase';

import { Button, ErrorNote, Modal } from './ui';

export interface ResetTarget {
  profile_id: string;
  name: string;
  phone: string | null;
}

export async function requestPasswordReset(profileId: string): Promise<string> {
  const { data, error } = await supabase().functions.invoke<{ temporary_password: string }>('admin-reset-password', {
    body: { profile_id: profileId },
  });
  if (error instanceof FunctionsHttpError) {
    const body = await (error.context as Response).json().catch(() => null);
    throw { message: body?.error };
  }
  if (error || !data?.temporary_password) throw { message: 'reset_unreachable' };
  return data.temporary_password;
}

export function ResetPasswordDialog({ target, onClose }: { target: ResetTarget; onClose: () => void }) {
  const [password, setPassword] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [copied, setCopied] = useState(false);

  async function reset() {
    setBusy(true);
    setError(null);
    try {
      setPassword(await requestPasswordReset(target.profile_id));
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  async function copy() {
    if (!password) return;
    await navigator.clipboard.writeText(password).catch(() => undefined);
    setCopied(true);
  }

  return (
    <Modal title="إعادة تعيين كلمة المرور" onClose={onClose} dismissible={!password}>
      <div className="flex flex-col gap-4">
        <p className="text-[15px] text-ink-2">
          {target.name}
          <span className="text-ink-3"> · </span>
          <span dir="ltr" className="inline-block whitespace-nowrap">
            {formatPhone(target.phone)}
          </span>
        </p>
        {password ? (
          <>
            <div className="rounded-card border-[1.5px] border-line bg-bg p-4 text-center">
              <div className="mb-1 text-caption text-ink-3">كلمة المرور المؤقتة</div>
              <div data-testid="temporary-password" dir="ltr" className="select-all font-mono text-[24px] font-extrabold tracking-wider text-ink">
                {password}
              </div>
            </div>
            <p className="rounded-ctl bg-warning-bg px-4 py-3 text-[14px] font-semibold text-warning-fg">
              تظهر هذه الكلمة مرة واحدة فقط. أرسلها إلى صاحب الحساب عبر واتساب. سيُطلب منه اختيار كلمة مرور جديدة عند الدخول، وقد خرج من كل أجهزته.
            </p>
            <div className="flex gap-3">
              <Button size="lg" className="flex-1" onClick={copy}>
                {copied ? <Check size={18} /> : <Copy size={18} />}
                {copied ? 'تم النسخ' : 'نسخ كلمة المرور'}
              </Button>
              <Button variant="secondary" size="lg" onClick={onClose}>
                تم
              </Button>
            </div>
          </>
        ) : (
          <>
            <p className="text-[14px] text-ink-3">سيتم إنشاء كلمة مرور مؤقتة جديدة، وتتوقف كلمة المرور الحالية عن العمل فوراً.</p>
            {error && <ErrorNote message={error} />}
            <div className="flex gap-3">
              <Button variant="accent" size="lg" className="flex-1" busy={busy} onClick={reset}>
                إنشاء كلمة مرور مؤقتة
              </Button>
              <Button variant="secondary" size="lg" onClick={onClose}>
                إلغاء
              </Button>
            </div>
          </>
        )}
      </div>
    </Modal>
  );
}
