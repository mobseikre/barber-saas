export type NotificationType = 'booking_created' | 'booking_cancelled' | 'booking_reminder';
export type Audience = 'barber' | 'customer';
export type CancelledBy = 'customer' | 'barber' | 'admin';

/** The body that the `bookings_notify` trigger and `send_booking_reminders` post. */
export interface NotificationPayload {
  type: NotificationType;
  booking_id: string;
  recipient_id: string;
  audience: Audience;
  starts_at: string;
  barber_name: string;
  salon_name: string;
  customer_name?: string;
  service_name: string;
  cancelled_by?: CancelledBy;
  cancel_reason?: 'sick' | 'emergency' | 'other';
  cancel_note?: string;
}

/** The body that the `barbers_notify_activation` trigger posts. */
export interface ActivationPayload {
  type: 'barber_activated';
  recipient_id: string;
  audience: 'barber';
  barber_name: string;
  /** Customers can book the barber now; otherwise the account is active but the subscription is not. */
  bookable: boolean;
  /** The barber was active before, so a lapsed subscription was renewed. */
  renewed: boolean;
}

export interface PushMessage {
  title: string;
  body: string;
  data: Record<string, string>;
}

const timezone = 'Africa/Tripoli';

/** Mirrors `BarberCancelReason.labelAr`. */
const cancelReasons = { sick: 'مريض', emergency: 'ظرف طارئ', other: 'سبب آخر' } as const;

const dayFormat = new Intl.DateTimeFormat('ar', {
  timeZone: timezone,
  numberingSystem: 'latn',
  weekday: 'long',
  day: 'numeric',
  month: 'long',
});
const timeFormat = new Intl.DateTimeFormat('ar', {
  timeZone: timezone,
  numberingSystem: 'latn',
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
});

/** يوم الخميس، 15 أكتوبر الساعة 7:30 م */
function when(startsAt: Date): string {
  return `يوم ${dayFormat.format(startsAt)} الساعة ${timeFormat.format(startsAt)}`;
}

function reason(p: NotificationPayload): string {
  if (!p.cancel_reason) return '';
  const note = p.cancel_note?.trim();
  if (p.cancel_reason === 'other' && note) return ` السبب: ${note}`;
  return ` السبب: ${cancelReasons[p.cancel_reason]}${note ? ` — ${note}` : ''}`;
}

function text(p: NotificationPayload, startsAt: Date): { title: string; body: string } | null {
  const customer = p.customer_name ?? 'زبون';
  switch (p.type) {
    case 'booking_created':
      return { title: 'حجز جديد', body: `${customer} حجز ${p.service_name} ${when(startsAt)}` };
    case 'booking_reminder':
      return {
        title: 'تذكير بموعدك',
        body: `موعدك مع ${p.barber_name} في ${p.salon_name} الساعة ${timeFormat.format(startsAt)}`,
      };
    case 'booking_cancelled':
      if (p.audience === 'barber') {
        return {
          title: 'تم إلغاء حجز',
          body: p.cancelled_by === 'admin'
            ? `ألغت الإدارة حجز ${customer} ${when(startsAt)}`
            : `ألغى ${customer} حجز ${p.service_name} ${when(startsAt)}`,
        };
      }
      return {
        title: 'تم إلغاء موعدك',
        body:
          (p.cancelled_by === 'admin'
            ? `ألغت الإدارة موعدك مع ${p.barber_name} ${when(startsAt)}.`
            : `ألغى ${p.barber_name} موعدك ${when(startsAt)}.`) + reason(p),
      };
    default:
      return null;
  }
}

function activation(p: ActivationPayload): { title: string; body: string } {
  if (!p.bookable) {
    return { title: 'تم تفعيل حسابك', body: 'فعّل اشتراكك مع الإدارة ليظهر حسابك للزبائن ويحجزوا عندك.' };
  }
  return p.renewed
    ? { title: 'تم تجديد اشتراكك', body: 'عاد حسابك للظهور للزبائن ويمكنهم الحجز عندك الآن.' }
    : { title: 'تم تفعيل حسابك', body: 'حسابك ظاهر للزبائن الآن ويمكنهم الحجز عندك.' };
}

/** The Arabic notification for [payload], or null when the payload is not one we send. */
export function composeMessage(payload: unknown): PushMessage | null {
  if (typeof payload !== 'object' || payload === null) return null;
  if ((payload as { type?: unknown }).type === 'barber_activated') {
    const a = payload as ActivationPayload;
    if (typeof a.recipient_id !== 'string' || a.audience !== 'barber') return null;
    return { ...activation(a), data: { type: a.type } };
  }
  const p = payload as NotificationPayload;
  if (typeof p.booking_id !== 'string' || typeof p.recipient_id !== 'string') return null;
  if (p.audience !== 'barber' && p.audience !== 'customer') return null;
  const startsAt = new Date(p.starts_at);
  if (Number.isNaN(startsAt.getTime())) return null;
  const t = text(p, startsAt);
  return t && { ...t, data: { type: p.type, booking_id: p.booking_id } };
}
