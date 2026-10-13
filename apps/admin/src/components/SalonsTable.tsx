'use client';

import { Star } from 'lucide-react';
import Link from 'next/link';
import { useMemo, useState } from 'react';

import { must } from '@/lib/db';
import { supabase } from '@/lib/supabase';
import type { AdminSalon } from '@/lib/types';
import { useAsync } from '@/lib/useAsync';

import { Cell, Chips, Empty, ErrorNote, Loading, Row, SearchInput, Table } from './ui';

export function SalonsTable({ limit, searchable }: { limit?: number; searchable?: boolean }) {
  const [city, setCity] = useState('all');
  const [query, setQuery] = useState('');
  const salons = useAsync(() => must<AdminSalon[]>(supabase().from('admin_salons').select('*').order('created_at', { ascending: true })), []);

  const cities = useMemo(() => [...new Map((salons.data ?? []).map((s) => [s.city_id, s.city_name])).entries()], [salons.data]);
  const rows = useMemo(() => {
    const term = query.trim();
    const filtered = (salons.data ?? []).filter((s) => (city === 'all' || s.city_id === city) && (!term || s.name.includes(term) || s.area_name.includes(term)));
    return limit ? filtered.slice(0, limit) : filtered;
  }, [salons.data, city, query, limit]);

  if (salons.loading && !salons.data) return <Loading />;
  if (salons.error) return <ErrorNote message={salons.error} onRetry={salons.reload} />;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <Chips value={city} onChange={setCity} options={[{ value: 'all', label: 'كل المدن' }, ...cities.map(([id, name]) => ({ value: id, label: name }))]} />
        {searchable && <SearchInput value={query} onChange={setQuery} placeholder="ابحث باسم الصالون أو المنطقة" />}
      </div>
      <Table head={['الصالون', 'المنطقة', 'الحلاقون المشتركون', 'حجوزات الشهر', 'التقييم', '']} empty={rows.length === 0 && <Empty>لا توجد صالونات</Empty>}>
        {rows.map((salon) => (
          <Row key={salon.id}>
            <Cell className="font-bold text-ink">{salon.name}</Cell>
            <Cell>
              {salon.area_name}، {salon.city_name}
            </Cell>
            <Cell>
              <div className="flex items-center gap-3">
                <span className="whitespace-nowrap font-bold text-ink">
                  {salon.barbers_subscribed} من {salon.barbers_total}
                </span>
                <span className="h-1.5 w-24 overflow-hidden rounded-full bg-blue-100" aria-hidden>
                  <span className="block h-full rounded-full bg-red-pole" style={{ width: `${salon.barbers_total ? (salon.barbers_subscribed / salon.barbers_total) * 100 : 0}%` }} />
                </span>
              </div>
            </Cell>
            <Cell className="font-bold text-ink">{salon.bookings_month}</Cell>
            <Cell>
              {Number(salon.rating_avg) > 0 ? (
                <span className="inline-flex items-center gap-1 font-bold text-ink">
                  {Number(salon.rating_avg).toFixed(1)} <Star size={14} className="fill-red-400 text-red-400" />
                </span>
              ) : (
                '—'
              )}
            </Cell>
            <Cell>
              <Link href={`/salons/${salon.id}`} className="font-bold text-red-700 hover:underline">
                إدارة الحلاقين
              </Link>
            </Cell>
          </Row>
        ))}
      </Table>
    </div>
  );
}
