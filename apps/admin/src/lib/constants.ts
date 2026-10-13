export const EXPIRING_SOON_DAYS = 5;
export const EXPIRING_OVERVIEW_DAYS = 7;
export const PAGE_SIZE = 25;
export const TRIPOLI_TIMEZONE = 'Africa/Tripoli';

export const NO_SHOW_LIMIT = 3;
export const NOTE_MAX_LENGTH = 200;
export const SEARCH_MAX_LENGTH = 60;
export const SUBSCRIPTION_MONTHS_MAX = 24;
export const SUBSCRIPTION_AMOUNT_MAX = 10000;

const PLAN_LABELS: Record<number, string> = { 1: 'شهري', 3: 'ربع سنوي', 6: 'نصف سنوي', 12: 'سنوي' };

export function planLabel(months: number): string {
  return PLAN_LABELS[months] ?? monthsText(months);
}

export function monthsText(months: number): string {
  if (months === 1) return 'شهر واحد';
  if (months === 2) return 'شهران';
  if (months <= 10) return `${months} أشهر`;
  return `${months} شهراً`;
}
