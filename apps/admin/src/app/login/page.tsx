'use client';

import { useRouter, useSearchParams } from 'next/navigation';
import { Suspense, useState, type FormEvent } from 'react';

import { PoleMark } from '@/components/Logo';
import { Button, Field, Input } from '@/components/ui';
import { toInternalEmail } from '@/lib/phone';
import { supabase } from '@/lib/supabase';

function LoginForm() {
  const router = useRouter();
  const denied = useSearchParams().get('denied') === '1';
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    const email = toInternalEmail(phone);
    if (!email) {
      setError('رقم الهاتف غير صحيح');
      return;
    }
    setBusy(true);
    setError(null);
    const { error: signInError } = await supabase().auth.signInWithPassword({ email, password });
    if (signInError) {
      setError('رقم الهاتف أو كلمة المرور غير صحيحة');
      setBusy(false);
      return;
    }
    const { data: isAdmin } = await supabase().rpc('is_admin');
    if (isAdmin !== true) {
      await supabase().auth.signOut();
      setError('هذا الحساب ليس حساب إدارة');
      setBusy(false);
      return;
    }
    router.replace('/');
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-bg p-4">
      <div className="w-full max-w-md overflow-hidden rounded-panel bg-white shadow-card">
        <div className="flex flex-col items-center gap-3 rounded-b-[28px] bg-blue-900 px-6 pb-8 pt-10 text-center">
          <PoleMark size={64} />
          <h1 className="text-h1 text-white">تسجيل الدخول</h1>
          <p className="text-caption text-onDark">لوحة إدارة حلّاقي</p>
        </div>
        <form onSubmit={submit} className="flex flex-col gap-4 p-6" noValidate>
          {denied && (
            <p role="alert" className="rounded-ctl bg-danger-bg px-4 py-3 text-[14px] font-semibold text-danger-fg">
              هذا الحساب ليس حساب إدارة، تم تسجيل الخروج
            </p>
          )}
          <Field label="رقم الهاتف">
            {(id) => (
              <div className="flex items-stretch overflow-hidden rounded-ctl border-[1.5px] border-line focus-within:border-red-400 focus-within:shadow-ring" dir="ltr">
                <span className="flex items-center border-e border-line bg-bg px-4 text-[15px] font-semibold">+218</span>
                <input
                  id={id}
                  inputMode="tel"
                  autoComplete="username"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="91 234 5678"
                  className="h-[49px] min-w-0 flex-1 bg-white px-4 text-[15px] outline-none placeholder:text-ink-3"
                />
              </div>
            )}
          </Field>
          <Field label="كلمة المرور" error={error}>
            {(id) => (
              <Input id={id} type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} invalid={!!error} />
            )}
          </Field>
          <Button type="submit" size="lg" busy={busy} disabled={!phone || !password}>
            تسجيل الدخول
          </Button>
        </form>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  );
}
