'use client';

import { useState } from 'react';

import { ConfirmDialog } from '@/components/Confirm';
import { ResetPasswordDialog } from '@/components/ResetPasswordDialog';
import { Avatar, Badge, Button, Card, Cell, Chips, Empty, ErrorNote, Loading, PageHeader, Pill, Row, SearchInput, Table, useToast } from '@/components/ui';
import { NO_SHOW_LIMIT, PAGE_SIZE } from '@/lib/constants';
import { containsFilter, must, searchTerm } from '@/lib/db';
import { errorMessage } from '@/lib/errors';
import { formatDate } from '@/lib/format';
import { formatPhone, phoneSearchTerm } from '@/lib/phone';
import { supabase } from '@/lib/supabase';
import type { Customer } from '@/lib/types';
import { useAsync, useDebounced } from '@/lib/useAsync';

type Filter = 'all' | 'blocked' | 'no_shows';

export default function CustomersPage() {
  const { notify } = useToast();
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<Filter>('all');
  const [limit, setLimit] = useState(PAGE_SIZE);
  const [unblocking, setUnblocking] = useState<Customer | null>(null);
  const [resetting, setResetting] = useState<Customer | null>(null);
  const term = useDebounced(query);

  const list = useAsync(async () => {
    let request = supabase().from('profiles').select('id,full_name,phone,no_show_count,blocked_at,created_at').eq('role', 'customer');
    const text = searchTerm(term);
    if (text) {
      const digits = phoneSearchTerm(text);
      request = request.or(digits ? `${containsFilter('full_name', text)},${containsFilter('phone', digits)}` : containsFilter('full_name', text));
    }
    if (filter === 'blocked') request = request.not('blocked_at', 'is', null);
    if (filter === 'no_shows') request = request.gt('no_show_count', 0);
    return must<Customer[]>(request.order('created_at', { ascending: false }).limit(limit + 1));
  }, [term, filter, limit]);

  const rows = (list.data ?? []).slice(0, limit);

  async function unblock(customer: Customer) {
    const { error } = await supabase().rpc('unblock_customer', { p_profile_id: customer.id });
    if (error) notify(errorMessage(error), 'error');
    else {
      notify(`تم فك الحظر عن ${customer.full_name}`);
      list.reload();
    }
  }

  return (
    <>
      <PageHeader title="الزبائن" subtitle={`يُحظر الزبون بعد ${NO_SHOW_LIMIT} مرات لم يحضر فيها، ولا يرفع الحظر إلا الإدارة`} />
      <Card className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Chips
            value={filter}
            onChange={(value) => {
              setFilter(value);
              setLimit(PAGE_SIZE);
            }}
            options={[
              { value: 'all', label: 'الكل' },
              { value: 'blocked', label: 'المحظورون' },
              { value: 'no_shows', label: 'لديهم غيابات' },
            ]}
          />
          <SearchInput
            value={query}
            onChange={(value) => {
              setQuery(value);
              setLimit(PAGE_SIZE);
            }}
            placeholder="ابحث بالاسم أو رقم الهاتف"
          />
        </div>
        {list.loading && !list.data ? (
          <Loading />
        ) : list.error ? (
          <ErrorNote message={list.error} onRetry={list.reload} />
        ) : (
          <>
            <Table head={['الزبون', 'الهاتف', 'لم يحضر', 'الحالة', 'التسجيل', 'الإجراء']} empty={rows.length === 0 && <Empty>لا يوجد زبائن مطابقون</Empty>}>
              {rows.map((c) => (
                <Row key={c.id}>
                  <Cell>
                    <div className="flex items-center gap-3">
                      <Avatar name={c.full_name} />
                      <span className="font-bold text-ink">{c.full_name}</span>
                    </div>
                  </Cell>
                  <Cell>
                    <span dir="ltr" className="inline-block whitespace-nowrap">{formatPhone(c.phone)}</span>
                  </Cell>
                  <Cell>
                    <span className="font-bold text-ink" data-testid="no-show-count">{c.no_show_count}</span>
                  </Cell>
                  <Cell>{c.blocked_at ? <Badge tone="danger">محظور</Badge> : c.no_show_count > 0 ? <Pill tone="warning">تحذير</Pill> : <Pill tone="success">سليم</Pill>}</Cell>
                  <Cell>{formatDate(c.created_at)}</Cell>
                  <Cell>
                    <div className="flex flex-wrap gap-2">
                      {(c.blocked_at || c.no_show_count > 0) && (
                        <Button size="sm" variant={c.blocked_at ? 'accent' : 'secondary'} onClick={() => setUnblocking(c)}>
                          {c.blocked_at ? 'فك الحظر' : 'تصفير العدّاد'}
                        </Button>
                      )}
                      <Button size="sm" variant="secondary" onClick={() => setResetting(c)}>
                        كلمة المرور
                      </Button>
                    </div>
                  </Cell>
                </Row>
              ))}
            </Table>
            {(list.data ?? []).length > limit && (
              <Button variant="secondary" className="self-center" onClick={() => setLimit((n) => n + PAGE_SIZE)}>
                عرض المزيد
              </Button>
            )}
          </>
        )}
      </Card>
      {unblocking && (
        <ConfirmDialog title={unblocking.blocked_at ? `فك الحظر عن ${unblocking.full_name}؟` : `تصفير عدّاد ${unblocking.full_name}؟`} confirmLabel={unblocking.blocked_at ? 'فك الحظر' : 'تصفير العدّاد'} onConfirm={() => unblock(unblocking)} onClose={() => setUnblocking(null)}>
          سيعود عدد مرات لم يحضر إلى 0 ويستطيع الحجز من جديد.
        </ConfirmDialog>
      )}
      {resetting && <ResetPasswordDialog target={{ profile_id: resetting.id, name: resetting.full_name, phone: resetting.phone }} onClose={() => setResetting(null)} />}
    </>
  );
}
