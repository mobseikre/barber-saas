import { EXPIRING_SOON_DAYS } from './constants';
import type { AdminBarber, CancelReason } from './types';
import { subscriptionState, type SubscriptionState } from '@/components/ui';

export const CANCEL_REASON_LABELS: Record<CancelReason, string> = {
  sick: 'مريض',
  emergency: 'طارئ',
  other: 'أخرى',
};

export function barberSubscription(barber: AdminBarber): SubscriptionState {
  if (!barber.profile_id) return 'none';
  return subscriptionState(barber.subscription_ends_at, EXPIRING_SOON_DAYS);
}
