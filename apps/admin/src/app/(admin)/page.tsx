'use client';

import { Search } from 'lucide-react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';

import { ExpiringList } from '@/components/ExpiringList';
import { PendingQueue } from '@/components/PendingQueue';
import { SalonsTable } from '@/components/SalonsTable';
import { Card, ErrorNote, Loading, PageHeader } from '@/components/ui';
import { EXPIRING_OVERVIEW_DAYS } from '@/lib/constants';
import { must, mustCount } from '@/lib/db';
import { daysFromNow, formatWeekdayDate } from '@/lib/format';
import { supabase } from '@/lib/supabase';
import { useAsync } from '@/lib/useAsync';

function Kpi({ label, value, hint, dark, hintTone }: { label: string; value: number | string; hint: string; dark?: boolean; hintTone?: 'red' }) {
  return (
    <div className={`rounded-card p-4 ${dark ? 'bg-blue-900 text-white' : 'bg-white shadow-card'}`}>
      <div className={`text-[13px] ${dark ? 'text-onDark' : 'text-ink-2'}`}>{label}</div>
      <div className={`text-[32px] font-extrabold leading-[44px] ${dark ? 'text-white' : 'text-ink'}`}>{value}</div>
      <div className={`text-[13px] font-semibold ${dark ? 'text-red-300' : hintTone === 'red' ? 'text-red-700' : 'text-ink-3'}`}>{hint}</div>
    </div>
  );
}

interface TodayCounts {
  total: number;
  no_show: number;
}

async function loadKpis() {
  const db = supabase();
  const [pending, bookable, registered, salons, expiring, today, cities] = await Promise.all([
    mustCount(db.from('admin_barbers').select('id', { count: 'exact', head: true }).eq('status', 'pending')),
    mustCount(db.from('admin_barbers').select('id', { count: 'exact', head: true }).eq('is_bookable', true)),
    mustCount(db.from('admin_barbers').select('id', { count: 'exact', head: true }).not('profile_id', 'is', null).neq('status', 'rejected')),
    mustCount(db.from('admin_salons').select('id', { count: 'exact', head: true })),
    mustCount(db.from('admin_barbers').select('id', { count: 'exact', head: true }).eq('status', 'active').gt('subscription_ends_at', new Date().toISOString()).lte('subscription_ends_at', daysFromNow(EXPIRING_OVERVIEW_DAYS))),
    must<TodayCounts>(db.rpc('admin_today_counts').single()),
    must<{ city_id: string }[]>(db.from('admin_salons').select('city_id')),
  ]);
  return { pending, bookable, registered, salons, expiring, bookingsToday: today.total, noShowsToday: today.no_show, cities: new Set(cities.map((s) => s.city_id)).size };
}

export default function OverviewPage() {
  const router = useRouter();
  const [query, setQuery] = useState('');
  const kpis = useAsync(loadKpis, []);

  function search(event: FormEvent) {
    event.preventDefault();
    router.push(`/barbers?q=${encodeURIComponent(query.trim())}`);
  }

  const k = kpis.data;

  return (
    <>
      <PageHeader
        title="نظرة عامة"
        subtitle={formatWeekdayDate(new Date())}
        actions={
          <form onSubmit={search} role="search" className="relative w-full max-w-xs">
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="ابحث باسم حلاق، صالون أو رقم هاتف"
              aria-label="بحث"
              className="h-11 w-full rounded-ctl border-[1.5px] border-line bg-white pe-10 ps-4 text-[14px] outline-none placeholder:text-ink-3 focus:border-red-400 focus:shadow-ring"
            />
            <Search size={18} className="pointer-events-none absolute end-3 top-1/2 -translate-y-1/2 text-ink-3" />
          </form>
        }
      />

      {kpis.error && <ErrorNote message={kpis.error} onRetry={kpis.reload} />}
      {!k && !kpis.error && <Loading />}
      {k && (
        <div className="grid grid-cols-2 gap-4 lg:grid-cols-3 min-[1400px]:grid-cols-5">
          <Kpi dark label="طلبات بانتظار التفعيل" value={k.pending} hint={k.pending ? 'تحتاج إلى مراجعة' : 'لا توجد طلبات'} />
          <Kpi label="حلاقون مشتركون" value={k.bookable} hint={`المسجلون: ${k.registered}`} hintTone="red" />
          <Kpi label="صالونات" value={k.salons} hint={`المدن: ${k.cities}`} hintTone="red" />
          <Kpi label={`اشتراكات تنتهي خلال ${EXPIRING_OVERVIEW_DAYS} أيام`} value={k.expiring} hint="تحتاج تواصلاً للتجديد" hintTone="red" />
          <Kpi label="حجوزات اليوم" value={k.bookingsToday} hint={`لم يحضر: ${k.noShowsToday}`} hintTone="red" />
        </div>
      )}

      <div className="mt-6 grid grid-cols-1 gap-6 min-[1400px]:grid-cols-[minmax(0,1.6fr)_minmax(0,1fr)]">
        <Card>
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-h2 text-ink">طلبات التفعيل الجديدة</h2>
            <Link href="/activation" className="text-[14px] font-bold text-red-700 hover:underline">
              عرض الكل
            </Link>
          </div>
          <PendingQueue limit={5} onChanged={kpis.reload} />
        </Card>
        <Card>
          <h2 className="text-h2 text-ink">اشتراكات تنتهي قريباً</h2>
          <p className="mb-2 text-caption text-ink-3">خلال {EXPIRING_OVERVIEW_DAYS} أيام · التجديد بالتواصل المباشر</p>
          <ExpiringList days={EXPIRING_OVERVIEW_DAYS} onChanged={kpis.reload} />
        </Card>
      </div>

      <Card className="mt-6">
        <h2 className="mb-4 text-h2 text-ink">الصالونات</h2>
        <SalonsTable limit={8} />
      </Card>
    </>
  );
}
