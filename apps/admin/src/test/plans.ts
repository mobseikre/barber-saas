import type { SubscriptionPlan } from '@/lib/types';

const plan = (months: number, price: number, is_active = true): SubscriptionPlan => ({
  id: `plan-${months}`,
  months,
  price,
  is_active,
  updated_at: '2026-10-01T10:00:00Z',
});

export const PLANS = [plan(1, 50), plan(3, 150), plan(6, 280), plan(12, 500)];
export const planWith = plan;
