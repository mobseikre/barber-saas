import { TRIPOLI_TIMEZONE } from './constants';

const locale = 'ar-LY-u-nu-latn';

const dateFormat = new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'long', year: 'numeric', timeZone: TRIPOLI_TIMEZONE });
const dayMonthFormat = new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'long', timeZone: TRIPOLI_TIMEZONE });
const weekdayDateFormat = new Intl.DateTimeFormat(locale, { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric', timeZone: TRIPOLI_TIMEZONE });
const timeFormat = new Intl.DateTimeFormat(locale, { hour: 'numeric', minute: '2-digit', hour12: true, timeZone: TRIPOLI_TIMEZONE });
const monthFormat = new Intl.DateTimeFormat(locale, { month: 'long', timeZone: TRIPOLI_TIMEZONE });
const isoDay = new Intl.DateTimeFormat('en-CA', { timeZone: TRIPOLI_TIMEZONE });
const offsetFormat = new Intl.DateTimeFormat('en-US', { timeZone: TRIPOLI_TIMEZONE, timeZoneName: 'longOffset' });

const MS_PER_DAY = 86_400_000;

export const formatDate = (value: string | Date) => dateFormat.format(new Date(value));
export const formatDayMonth = (value: string | Date) => dayMonthFormat.format(new Date(value));
export const formatWeekdayDate = (value: string | Date) => weekdayDateFormat.format(new Date(value));
export const formatTime = (value: string | Date) => timeFormat.format(new Date(value));
export const formatMonth = (value: string | Date) => monthFormat.format(new Date(value));
export const tripoliDay = (value: string | Date = new Date()) => isoDay.format(new Date(value));

export const formatPrice = (value: number | string) => `${Number(value).toLocaleString('en-US', { maximumFractionDigits: 2 })} د.ل`;

export function tripoliOffsetMinutes(at: Date): number {
  const name = offsetFormat.formatToParts(at).find((part) => part.type === 'timeZoneName')?.value ?? 'GMT';
  const match = /GMT([+-])(\d{2}):(\d{2})/.exec(name);
  if (!match) return 0;
  return (match[1] === '-' ? -1 : 1) * (Number(match[2]) * 60 + Number(match[3]));
}

function tripoliMidnight(day: string): Date {
  const [year, month, date] = day.split('-').map(Number);
  const utcMidnight = Date.UTC(year, month - 1, date);
  const guess = utcMidnight - tripoliOffsetMinutes(new Date(utcMidnight)) * 60_000;
  return new Date(utcMidnight - tripoliOffsetMinutes(new Date(guess)) * 60_000);
}

export function dayBounds(day: string): { from: string; to: string } {
  const [year, month, date] = day.split('-').map(Number);
  const next = new Date(Date.UTC(year, month - 1, date + 1)).toISOString().slice(0, 10);
  return { from: tripoliMidnight(day).toISOString(), to: tripoliMidnight(next).toISOString() };
}

export function addMonths(from: Date, months: number): Date {
  const target = new Date(from.getTime());
  const day = target.getUTCDate();
  target.setUTCDate(1);
  target.setUTCMonth(target.getUTCMonth() + months);
  const lastDay = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0)).getUTCDate();
  target.setUTCDate(Math.min(day, lastDay));
  return target;
}

export function daysFromNow(days: number): string {
  return new Date(Date.now() + days * MS_PER_DAY).toISOString();
}

export function daysUntil(value: string): number {
  return Math.ceil((new Date(value).getTime() - Date.now()) / MS_PER_DAY);
}

export function relativeDays(value: string): string {
  const days = daysUntil(value);
  if (days <= 0) return 'اليوم';
  if (days === 1) return 'غداً';
  if (days === 2) return 'بعد يومين';
  if (days <= 10) return `بعد ${days} أيام`;
  return `بعد ${days} يوماً`;
}

export function rangeStart(range: string | null): string | null {
  const match = /^\["?([^",]+)"?,/.exec(range ?? '');
  if (!match) return null;
  const parsed = new Date(match[1].replace(' ', 'T').replace(/([+-]\d{2})$/, '$1:00'));
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

