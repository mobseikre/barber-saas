'use client';

import { useState } from 'react';
import { Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { Card, Chips, ErrorNote, Loading, PageHeader } from '@/components/ui';
import { mustCount, must } from '@/lib/db';
import { formatDayMonth, formatMonth, formatPrice } from '@/lib/format';
import { supabase } from '@/lib/supabase';
import { useAsync } from '@/lib/useAsync';

interface DayRow {
  day: string;
  total: number;
  completed: number;
  cancelled: number;
  no_show: number;
}

interface MonthRow {
  month: string;
  revenue: number;
  payments: number;
}

const RANGES = [
  { value: '7', label: '7 أيام' },
  { value: '30', label: '30 يوماً' },
  { value: '90', label: '90 يوماً' },
];

const COLORS = { confirmed: '#1E4FB8', completed: '#16794A', no_show: '#A4520B', cancelled: '#B42318', revenue: '#D62828', grid: '#E8ECF4', text: '#4B5565' };

function Stat({ label, value, hint }: { label: string; value: number | string; hint?: string }) {
  return (
    <div className="rounded-card bg-blue-900 p-4 text-white">
      <div className="text-[13px] text-onDark">{label}</div>
      <div className="text-[32px] font-extrabold leading-[44px]">{value}</div>
      {hint && <div className="text-[13px] font-semibold text-red-300">{hint}</div>}
    </div>
  );
}

const axis = { fontSize: 12, fill: COLORS.text, fontFamily: 'Cairo' };
const tooltipStyle = { fontFamily: 'Cairo', borderRadius: 12, border: '1px solid #DCE1EC', direction: 'rtl' as const };

export default function ReportsPage() {
  const [range, setRange] = useState('30');

  const barbers = useAsync(async () => {
    const db = supabase();
    const count = (status: string) => mustCount(db.from('admin_barbers').select('id', { count: 'exact', head: true }).eq('status', status).not('profile_id', 'is', null));
    const [active, pending, suspended, bookable] = await Promise.all([
      count('active'),
      count('pending'),
      count('suspended'),
      mustCount(db.from('admin_barbers').select('id', { count: 'exact', head: true }).eq('is_bookable', true)),
    ]);
    return { active, pending, suspended, bookable };
  }, []);

  const days = useAsync(async () => {
    const rows = await must<DayRow[]>(supabase().rpc('admin_bookings_per_day', { p_days: Number(range) }));
    return rows.map((r) => ({ ...r, confirmed: r.total - r.completed - r.cancelled - r.no_show, label: formatDayMonth(`${r.day}T12:00:00+02:00`) }));
  }, [range]);

  const months = useAsync(async () => {
    const rows = await must<MonthRow[]>(supabase().rpc('admin_revenue_per_month', { p_months: 12 }));
    return rows.map((r) => ({ ...r, revenue: Number(r.revenue), label: formatMonth(`${r.month}T12:00:00+02:00`) }));
  }, []);

  const totalBookings = (days.data ?? []).reduce((sum, r) => sum + r.total, 0);
  const totalRevenue = (months.data ?? []).reduce((sum, r) => sum + r.revenue, 0);

  return (
    <>
      <PageHeader title="التقارير" subtitle="الحجوزات والحلاقون والاشتراكات بتوقيت طرابلس" />

      {barbers.error ? (
        <ErrorNote message={barbers.error} onRetry={barbers.reload} />
      ) : (
        <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
          <Stat label="حلاقون نشطون" value={barbers.data?.active ?? '—'} hint={barbers.data ? `${barbers.data.bookable} منهم مشتركون ويمكن الحجز معهم` : undefined} />
          <Stat label="بانتظار التفعيل" value={barbers.data?.pending ?? '—'} />
          <Stat label="حلاقون موقوفون" value={barbers.data?.suspended ?? '—'} />
          <Stat label={`حجوزات آخر ${range} يوماً`} value={days.data ? totalBookings : '—'} />
        </div>
      )}

      <Card className="mt-6">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <h2 className="text-h2 text-ink">الحجوزات حسب اليوم</h2>
          <Chips value={range} onChange={setRange} options={RANGES} />
        </div>
        {days.error ? (
          <ErrorNote message={days.error} onRetry={days.reload} />
        ) : !days.data ? (
          <Loading />
        ) : (
          <div dir="ltr" className="h-[320px]" data-testid="bookings-chart">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={days.data} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                <CartesianGrid stroke={COLORS.grid} vertical={false} />
                <XAxis dataKey="label" tick={axis} tickLine={false} interval="preserveStartEnd" minTickGap={24} />
                <YAxis tick={axis} tickLine={false} axisLine={false} allowDecimals={false} width={32} />
                <Tooltip contentStyle={tooltipStyle} cursor={{ fill: '#E7ECFA' }} />
                <Legend wrapperStyle={{ fontFamily: 'Cairo', fontSize: 13 }} />
                <Bar isAnimationActive={false} dataKey="completed" name="مكتمل" stackId="a" fill={COLORS.completed} />
                <Bar isAnimationActive={false} dataKey="confirmed" name="مؤكد" stackId="a" fill={COLORS.confirmed} />
                <Bar isAnimationActive={false} dataKey="no_show" name="لم يحضر" stackId="a" fill={COLORS.no_show} />
                <Bar isAnimationActive={false} dataKey="cancelled" name="ملغي" stackId="a" fill={COLORS.cancelled} radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </Card>

      <Card className="mt-6">
        <div className="mb-4 flex flex-wrap items-baseline justify-between gap-3">
          <h2 className="text-h2 text-ink">إيرادات الاشتراكات شهرياً</h2>
          <span className="text-[15px] font-bold text-red-700">الإجمالي آخر 12 شهراً: {formatPrice(totalRevenue)}</span>
        </div>
        {months.error ? (
          <ErrorNote message={months.error} onRetry={months.reload} />
        ) : !months.data ? (
          <Loading />
        ) : (
          <div dir="ltr" className="h-[300px]" data-testid="revenue-chart">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={months.data} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
                <CartesianGrid stroke={COLORS.grid} vertical={false} />
                <XAxis dataKey="label" tick={axis} tickLine={false} />
                <YAxis tick={axis} tickLine={false} axisLine={false} width={48} />
                <Tooltip contentStyle={tooltipStyle} cursor={{ fill: '#E7ECFA' }} formatter={(value) => [formatPrice(Number(value)), 'الإيراد']} />
                <Bar isAnimationActive={false} dataKey="revenue" name="الإيراد" fill={COLORS.revenue} radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </Card>
    </>
  );
}
