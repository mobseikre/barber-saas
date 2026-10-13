'use client';

import { useState } from 'react';

import { BookingStatusBadge, Button, Card, Cell, Chips, Empty, ErrorNote, Loading, PageHeader, Row, Table } from '@/components/ui';
import { CANCEL_REASON_LABELS } from '@/lib/barbers';
import { PAGE_SIZE } from '@/lib/constants';
import { must } from '@/lib/db';
import { dayBounds, formatDayMonth, formatPrice, formatTime, rangeStart, tripoliDay } from '@/lib/format';
import { formatPhone } from '@/lib/phone';
import { supabase } from '@/lib/supabase';
import type { BookingRow, BookingStatus } from '@/lib/types';
import { useAsync } from '@/lib/useAsync';

type Filter = 'all' | BookingStatus;

export default function BookingsPage() {
  const [day, setDay] = useState(tripoliDay());
  const [status, setStatus] = useState<Filter>('all');
  const [limit, setLimit] = useState(PAGE_SIZE);

  const list = useAsync(async () => {
    let request = supabase()
      .from('bookings')
      .select(
        'id,time_range,status,source,price,customer_name,cancel_reason,cancel_note,customer:profiles!bookings_customer_id_fkey(full_name,phone),barber:barbers!inner(display_name,salon:salons(name)),service:service_catalog(name_ar)',
      );
    if (day) {
      const { from, to } = dayBounds(day);
      request = request.overlaps('time_range', `[${from},${to})`);
    }
    if (status !== 'all') request = request.eq('status', status);
    const rows = await must<unknown[]>(request.order('time_range', { ascending: !!day }).limit(limit + 1));
    return rows as BookingRow[];
  }, [day, status, limit]);

  const rows = (list.data ?? []).slice(0, limit);

  return (
    <>
      <PageHeader title="الحجوزات" subtitle="كل حجوزات التطبيق والحجوزات اليدوية" />
      <Card className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Chips
            value={status}
            onChange={(value) => {
              setStatus(value);
              setLimit(PAGE_SIZE);
            }}
            options={[
              { value: 'all', label: 'الكل' },
              { value: 'confirmed', label: 'مؤكد' },
              { value: 'completed', label: 'مكتمل' },
              { value: 'no_show', label: 'لم يحضر' },
              { value: 'cancelled', label: 'ملغي' },
            ]}
          />
          <div className="flex items-center gap-2">
            {day ? (
              <>
                <input
                  type="date"
                  aria-label="اليوم"
                  value={day}
                  required
                  onChange={(e) => {
                    setDay(e.target.value || tripoliDay());
                    setLimit(PAGE_SIZE);
                  }}
                  className="h-11 rounded-ctl border-[1.5px] border-line bg-white px-3 text-[15px] outline-none focus:border-red-400 focus:shadow-ring"
                />
                <Button variant="secondary" size="md" onClick={() => setDay('')}>
                  كل الأيام
                </Button>
              </>
            ) : (
              <Button variant="secondary" size="md" onClick={() => setDay(tripoliDay())}>
                اختيار يوم
              </Button>
            )}
          </div>
        </div>
        {list.loading && !list.data ? (
          <Loading />
        ) : list.error ? (
          <ErrorNote message={list.error} onRetry={list.reload} />
        ) : (
          <>
            <Table head={['الوقت', 'الزبون', 'الحلاق', 'الخدمة', 'السعر', 'الحالة']} empty={rows.length === 0 && <Empty>لا توجد حجوزات</Empty>}>
              {rows.map((b) => {
                const start = rangeStart(b.time_range);
                return (
                  <Row key={b.id}>
                    <Cell className="font-extrabold text-ink">
                      <span className="whitespace-nowrap">{start ? formatTime(start) : '—'}</span>
                      {!day && start && <div className="text-caption font-medium text-ink-3">{formatDayMonth(start)}</div>}
                    </Cell>
                    <Cell>
                      <div className="font-bold text-ink">{b.customer?.full_name ?? b.customer_name ?? '—'}</div>
                      <div className="text-caption text-ink-3">{b.source === 'manual' ? 'حجز يدوي' : <span dir="ltr" className="inline-block whitespace-nowrap">{formatPhone(b.customer?.phone)}</span>}</div>
                    </Cell>
                    <Cell>
                      <div className="font-semibold text-ink">{b.barber?.display_name}</div>
                      <div className="text-caption text-ink-3">{b.barber?.salon?.name}</div>
                    </Cell>
                    <Cell>{b.service?.name_ar}</Cell>
                    <Cell className="font-bold text-red-700">{formatPrice(b.price)}</Cell>
                    <Cell>
                      <BookingStatusBadge status={b.status} />
                      {b.cancel_reason && <div className="mt-1 text-caption text-ink-3">{CANCEL_REASON_LABELS[b.cancel_reason]}</div>}
                    </Cell>
                  </Row>
                );
              })}
            </Table>
            {(list.data ?? []).length > limit && (
              <Button variant="secondary" className="self-center" onClick={() => setLimit((n) => n + PAGE_SIZE)}>
                عرض المزيد
              </Button>
            )}
          </>
        )}
      </Card>
    </>
  );
}
