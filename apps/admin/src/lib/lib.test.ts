import { afterEach, describe, expect, it, vi } from 'vitest';

import { describeAction } from './audit';
import { containsFilter, searchTerm } from './db';
import { addMonths, dayBounds, relativeDays, tripoliOffsetMinutes } from './format';
import type { AdminAction } from './types';

afterEach(() => vi.useRealTimers());

describe('relativeDays', () => {
  it.each([
    [0, 'اليوم'],
    [1, 'غداً'],
    [2, 'بعد يومين'],
    [3, 'بعد 3 أيام'],
    [10, 'بعد 10 أيام'],
    [11, 'بعد 11 يوماً'],
    [30, 'بعد 30 يوماً'],
  ])('%i days', (days, text) => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-10-13T08:00:00Z'));
    expect(relativeDays(new Date(Date.now() + days * 86_400_000).toISOString())).toBe(text);
  });
});

describe('Tripoli day bounds come from Intl, not a fixed offset', () => {
  it('reads the zone offset', () => {
    expect(tripoliOffsetMinutes(new Date('2026-07-01T00:00:00Z'))).toBe(120);
  });

  it('starts the day at Tripoli midnight', () => {
    expect(dayBounds('2026-10-13')).toEqual({ from: '2026-10-12T22:00:00.000Z', to: '2026-10-13T22:00:00.000Z' });
    expect(dayBounds('2026-12-31')).toEqual({ from: '2026-12-30T22:00:00.000Z', to: '2026-12-31T22:00:00.000Z' });
  });
});

describe('addMonths', () => {
  it('clamps to the last day of the target month', () => {
    expect(addMonths(new Date('2026-01-31T12:00:00Z'), 1).toISOString()).toBe('2026-02-28T12:00:00.000Z');
    expect(addMonths(new Date('2026-12-31T12:00:00Z'), 2).toISOString()).toBe('2027-02-28T12:00:00.000Z');
    expect(addMonths(new Date('2026-05-15T12:00:00Z'), 24).toISOString()).toBe('2028-05-15T12:00:00.000Z');
  });
});

describe('customer search', () => {
  it('trims, drops control characters and caps the length', () => {
    expect(searchTerm('  خالد\n ')).toBe('خالد');
    expect(Array.from(searchTerm('ا'.repeat(100)))).toHaveLength(60);
  });

  it('quotes the value and escapes LIKE wildcards', () => {
    expect(containsFilter('full_name', 'خالد')).toBe('full_name.ilike."%خالد%"');
    expect(containsFilter('full_name', '50%_off')).toBe('full_name.ilike."%50\\\\%\\\\_off%"');
    expect(containsFilter('full_name', 'a,b)"c')).toBe('full_name.ilike."%a,b)\\"c%"');
  });
});

describe('describeAction', () => {
  const action = (over: Partial<AdminAction>): AdminAction => ({
    id: 'a1',
    actor_id: 'admin',
    action: 'set_barber_status',
    target_id: 'b1',
    details: {},
    created_at: '2026-10-13T08:00:00Z',
    actor: { full_name: 'الإدارة' },
    ...over,
  });

  it('names status changes', () => {
    expect(describeAction(action({ details: { from: 'pending', to: 'active' } })).label).toBe('اعتماد حلاق');
    expect(describeAction(action({ details: { from: 'active', to: 'suspended' } })).label).toBe('إيقاف حلاق');
  });

  it('shows the override reason next to the plan price', () => {
    const d = describeAction(
      action({ action: 'activate_subscription', details: { months: 1, amount: 40, plan_price: 50, override_reason: 'خصم', period_end: '2026-11-13T08:00:00Z' } }),
    );
    expect(d.label).toBe('تفعيل اشتراك');
    expect(d.details).toBe('شهري · 40 د.ل · سبب التعديل: خصم (سعر الباقة 50 د.ل) · حتى 13 نوفمبر 2026');
  });

  it('describes resets, unblocks and plan edits', () => {
    expect(describeAction(action({ action: 'reset_password', details: { role: 'barber' } }))).toEqual({ label: 'إعادة تعيين كلمة المرور', details: 'حساب حلاق' });
    expect(describeAction(action({ action: 'unblock_customer', details: { no_show_count: 3 } })).details).toBe('الغيابات قبلها: 3');
    expect(describeAction(action({ action: 'save_subscription_plan', details: { months: 3, price: 160, is_active: false } })).details).toBe('ربع سنوي · 160 د.ل · موقوفة');
  });
});
