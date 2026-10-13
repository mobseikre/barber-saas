import { planLabel } from './constants';
import { formatDate, formatPrice } from './format';
import type { AdminAction } from './types';

export type AuditKind = AdminAction['action'];

export const AUDIT_FILTERS: { value: AuditKind | 'all'; label: string }[] = [
  { value: 'all', label: 'الكل' },
  { value: 'set_barber_status', label: 'حالة الحلاقين' },
  { value: 'activate_subscription', label: 'الاشتراكات' },
  { value: 'unblock_customer', label: 'فك الحظر' },
  { value: 'save_subscription_plan', label: 'الباقات' },
  { value: 'reset_password', label: 'كلمات المرور' },
];

const STATUS_CHANGES: Record<string, string> = {
  'pending>active': 'اعتماد حلاق',
  'pending>rejected': 'رفض حلاق',
  'active>suspended': 'إيقاف حلاق',
  'suspended>active': 'إعادة تفعيل حلاق',
};

const text = (value: unknown) => (value == null ? '' : String(value));

export function describeAction(action: AdminAction): { label: string; details: string } {
  const d = action.details;
  switch (action.action) {
    case 'set_barber_status':
      return { label: STATUS_CHANGES[`${text(d.from)}>${text(d.to)}`] ?? 'تغيير حالة حلاق', details: '' };
    case 'activate_subscription':
      return {
        label: 'تفعيل اشتراك',
        details: [
          `${planLabel(Number(d.months))} · ${formatPrice(Number(d.amount))}`,
          d.override_reason ? `سبب التعديل: ${text(d.override_reason)} (سعر الباقة ${formatPrice(Number(d.plan_price))})` : null,
          d.period_end ? `حتى ${formatDate(text(d.period_end))}` : null,
        ]
          .filter(Boolean)
          .join(' · '),
      };
    case 'unblock_customer':
      return { label: 'فك الحظر وتصفير الغيابات', details: `الغيابات قبلها: ${text(d.no_show_count) || 0}` };
    case 'save_subscription_plan':
      return {
        label: 'تعديل باقة',
        details: `${planLabel(Number(d.months))} · ${formatPrice(Number(d.price))} · ${d.is_active ? 'متاحة' : 'موقوفة'}`,
      };
    case 'reset_password':
      return { label: 'إعادة تعيين كلمة المرور', details: d.role === 'barber' ? 'حساب حلاق' : 'حساب زبون' };
    default:
      return { label: text(action.action), details: '' };
  }
}
