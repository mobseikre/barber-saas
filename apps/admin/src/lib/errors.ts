import { SUBSCRIPTION_AMOUNT_MAX, SUBSCRIPTION_MONTHS_MAX } from './constants';

const MESSAGES: Record<string, string> = {
  admin_only: 'هذا الإجراء للإدارة فقط',
  barber_not_found: 'الحلاق غير موجود',
  barber_has_no_account: 'هذا الحلاق بلا حساب في التطبيق',
  invalid_barber_status: 'تغيّرت حالة الحلاق، حدّث الصفحة وأعد المحاولة',
  invalid_months: `مدة الباقة يجب أن تكون بين 1 و${SUBSCRIPTION_MONTHS_MAX} شهراً`,
  invalid_amount: `المبلغ يجب أن يكون بين 0 و${SUBSCRIPTION_AMOUNT_MAX} د.ل`,
  plan_not_found: 'هذه الباقة غير متاحة، حدّث الصفحة واختر باقة أخرى',
  override_reason_required: 'المبلغ يختلف عن سعر الباقة، اكتب سبب التعديل',
  override_reason_too_long: 'سبب التعديل طويل جداً',
  invalid_location: 'الموقع غير صحيح',
  salon_not_found: 'الصالون غير موجود',
  customer_not_found: 'الزبون غير موجود',
  profile_not_found: 'الحساب غير موجود',
  role_not_resettable: 'لا يمكن إعادة تعيين كلمة مرور هذا الحساب',
  password_update_failed: 'تعذّر تغيير كلمة المرور، أعد المحاولة',
  session_revoke_failed: 'تغيّرت كلمة المرور لكن تعذّر إنهاء جلسات الحساب، أعد المحاولة',
  audit_failed: 'تغيّرت كلمة المرور لكن تعذّر تسجيل الإجراء، أعد المحاولة',
  reset_unreachable: 'تعذّر الوصول إلى خدمة إعادة التعيين. تحقّق من الاتصال، أو من إعداد ADMIN_ALLOWED_ORIGINS على الخادم.',
  '23503': 'لا يمكن الحذف لأنه مرتبط ببيانات أخرى',
  '23505': 'هذا الاسم موجود مسبقاً',
};

export const GENERIC_ERROR = 'حدث خطأ، أعد المحاولة';

export function errorMessage(error: unknown): string {
  const code = (error as { code?: string } | null)?.code;
  const message = (error as { message?: string } | null)?.message;
  return MESSAGES[message ?? ''] ?? MESSAGES[code ?? ''] ?? GENERIC_ERROR;
}
