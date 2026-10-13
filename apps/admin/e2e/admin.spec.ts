import { expect, test } from '@playwright/test';

import { createCustomer, createPendingBarber, loginAsAdmin, PASSWORD, signedIn, signInResult, stamp } from './support';

test.describe('access', () => {
  test('a barber account is signed out with a message', async ({ page }) => {
    const barber = await createPendingBarber('دخول');
    await page.goto('/login');
    await page.getByLabel('رقم الهاتف').fill(barber.national);
    await page.getByLabel('كلمة المرور').fill(PASSWORD);
    await page.getByRole('button', { name: 'تسجيل الدخول' }).click();
    await expect(page.getByText('هذا الحساب ليس حساب إدارة')).toBeVisible();
    await expect(page).toHaveURL(/\/login/);
    await page.goto('/activation');
    await expect(page).toHaveURL(/\/login/);
  });

  test('a wrong password shows one error under the password field', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('رقم الهاتف').fill('0910000001');
    await page.getByLabel('كلمة المرور').fill('wrong-password');
    await page.getByRole('button', { name: 'تسجيل الدخول' }).click();
    await expect(page.getByText('رقم الهاتف أو كلمة المرور غير صحيحة')).toBeVisible();
  });

  test('visiting a page without a session goes to login', async ({ page }) => {
    await page.goto('/customers');
    await expect(page).toHaveURL(/\/login/);
  });
});

test.describe('barber approval', () => {
  test('approve a pending barber after correcting the salon pin', async ({ page }) => {
    const barber = await createPendingBarber('اعتماد');
    await loginAsAdmin(page);
    await page.goto('/activation');

    const row = page.getByRole('row').filter({ hasText: barber.name });
    await expect(row).toContainText(barber.salon);
    await expect(row).toContainText('صالون جديد');
    await row.getByRole('button', { name: 'تفعيل وتحديد الباقة' }).click();

    const dialog = page.getByRole('dialog');
    const map = dialog.getByTestId('salon-map');
    await expect(map).toBeVisible();
    await expect(dialog.getByTestId('coordinates')).toHaveText('32.87520, 13.11460');

    const box = (await map.boundingBox())!;
    await page.mouse.click(box.x + box.width * 0.3, box.y + box.height * 0.3);
    await expect(dialog.getByTestId('coordinates')).not.toHaveText('32.87520, 13.11460');
    const corrected = (await dialog.getByTestId('coordinates').textContent())!.split(', ').map(Number);

    await dialog.getByRole('checkbox').uncheck();
    await dialog.getByRole('button', { name: 'اعتماد بدون اشتراك' }).click();
    await expect(page.getByRole('status').filter({ hasText: 'تم اعتماد' })).toBeVisible();
    await expect(row).toHaveCount(0);

    const { data } = await barber.admin.from('admin_barbers').select('status,latitude,longitude,subscription_ends_at').eq('id', barber.barberId).single();
    expect(data!.status).toBe('active');
    expect(data!.subscription_ends_at).toBeNull();
    expect(data!.latitude).toBeCloseTo(corrected[0], 4);
    expect(data!.longitude).toBeCloseTo(corrected[1], 4);
  });

  test('reject a pending barber', async ({ page }) => {
    const barber = await createPendingBarber('رفض');
    await loginAsAdmin(page);
    await page.goto('/activation');
    const row = page.getByRole('row').filter({ hasText: barber.name });
    await row.getByRole('button', { name: 'رفض' }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'رفض الطلب' }).click();
    await expect(row).toHaveCount(0);
    const { data } = await barber.admin.from('admin_barbers').select('status').eq('id', barber.barberId).single();
    expect(data!.status).toBe('rejected');

    await page.getByRole('button', { name: 'المرفوضون' }).click();
    await expect(page.getByRole('row').filter({ hasText: barber.name })).toBeVisible();
  });

  test('suspend and reactivate an active barber', async ({ page }) => {
    const barber = await createPendingBarber('إيقاف');
    await barber.admin.rpc('approve_barber', { p_barber_id: barber.barberId });
    await loginAsAdmin(page);
    await page.goto('/barbers?q=' + encodeURIComponent(barber.name));
    const row = page.getByRole('row').filter({ hasText: barber.name });
    await expect(row).toContainText('نشط');
    await row.getByRole('button', { name: 'إيقاف' }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'إيقاف الحلاق' }).click();
    await expect(row).toContainText('موقوف');
    await row.getByRole('button', { name: 'إعادة تفعيل' }).click();
    await expect(row).toContainText('نشط');
  });
});

test.describe('subscriptions', () => {
  test('approve with a plan records the cash payment and makes the barber bookable', async ({ page }) => {
    const barber = await createPendingBarber('اشتراك');
    await loginAsAdmin(page);
    await page.goto('/activation');
    await page.getByRole('row').filter({ hasText: barber.name }).getByRole('button', { name: 'تفعيل وتحديد الباقة' }).click();
    const dialog = page.getByRole('dialog');
    const amount = dialog.getByLabel('المبلغ المدفوع نقداً (د.ل)');
    await expect(amount).toHaveValue('50');
    await dialog.getByLabel('الباقة').selectOption('3');
    await expect(amount).toHaveValue('150');
    await expect(amount).not.toBeEditable();
    await dialog.getByRole('button', { name: 'تفعيل وتحديد الباقة' }).click();
    await expect(page.getByRole('status').filter({ hasText: 'تم تفعيل' })).toBeVisible();

    const { data } = await barber.admin.from('admin_barbers').select('status,subscription_ends_at,is_bookable').eq('id', barber.barberId).single();
    expect(data!.status).toBe('active');
    expect(data!.is_bookable).toBe(true);
    const months = (new Date(data!.subscription_ends_at!).getTime() - Date.now()) / 86_400_000;
    expect(months).toBeGreaterThan(88);
    expect(months).toBeLessThan(93);

    const { data: payments } = await barber.admin.from('admin_subscription_payments').select('amount,note,recorded_by_name').eq('barber_id', barber.barberId);
    expect(payments).toHaveLength(1);
    expect(Number(payments![0].amount)).toBe(150);
    expect(payments![0].note).toBe('اشتراك ربع سنوي');
    expect(payments![0].recorded_by_name).toBe('الإدارة');

    await page.goto('/subscriptions');
    const log = page.getByRole('row').filter({ hasText: barber.name });
    await expect(log).toContainText('150 د.ل');
  });

  test('extending an existing subscription adds to its end date and the 5-day list shows ending ones', async ({ page }) => {
    const barber = await createPendingBarber('تمديد');
    await barber.admin.rpc('activate_subscription', { p_barber_id: barber.barberId, p_months: 1, p_amount: 50, p_note: null });
    const soon = new Date(Date.now() + 3 * 86_400_000).toISOString();
    const { error } = await barber.admin.from('barbers').update({ subscription_ends_at: soon }).eq('id', barber.barberId);
    expect(error).toBeNull();

    await loginAsAdmin(page);
    await page.goto('/subscriptions');
    const item = page.getByRole('listitem').filter({ hasText: barber.name });
    await expect(item).toContainText('بعد 3 أيام');
    await item.getByRole('button', { name: 'تجديد' }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog.getByLabel('المبلغ المدفوع نقداً (د.ل)')).toHaveValue('50');
    await dialog.getByRole('button', { name: 'تأكيد استلام المبلغ وتفعيل الاشتراك' }).click();
    await expect(item).toHaveCount(0);

    const { data } = await barber.admin.from('admin_barbers').select('subscription_ends_at').eq('id', barber.barberId).single();
    const days = (new Date(data!.subscription_ends_at!).getTime() - new Date(soon).getTime()) / 86_400_000;
    expect(days).toBeGreaterThan(27);
    expect(days).toBeLessThan(32);
  });

  test('a discounted amount needs a reason, which is stored with the payment and in the audit log', async ({ page }) => {
    const barber = await createPendingBarber('خصم');
    await barber.admin.rpc('approve_barber', { p_barber_id: barber.barberId });
    await loginAsAdmin(page);
    await page.goto('/subscriptions');
    await page.getByRole('button', { name: 'تفعيل اشتراك' }).click();
    await page.getByRole('dialog').getByLabel('الحلاق').selectOption({ label: `${barber.name} — ${barber.salon}` });
    await page.getByRole('dialog').getByRole('button', { name: 'متابعة' }).click();
    const dialog = page.getByRole('dialog');
    const confirm = dialog.getByRole('button', { name: 'تأكيد استلام المبلغ وتفعيل الاشتراك' });
    await dialog.getByRole('button', { name: 'تعديل المبلغ' }).click();
    await dialog.getByLabel('المبلغ المدفوع نقداً (د.ل)').fill('40');
    await expect(confirm).toBeDisabled();
    await dialog.getByLabel('سبب تعديل المبلغ').fill('خصم الشهر الأول');
    await confirm.click();
    await expect(page.getByRole('status').filter({ hasText: 'تم تفعيل' })).toBeVisible();

    const { data: payments } = await barber.admin.from('admin_subscription_payments').select('amount,override_reason,plan_price').eq('barber_id', barber.barberId);
    expect(payments).toHaveLength(1);
    expect(Number(payments![0].amount)).toBe(40);
    expect(Number(payments![0].plan_price)).toBe(50);
    expect(payments![0].override_reason).toBe('خصم الشهر الأول');

    await page.goto('/audit');
    const entry = page.getByRole('row').filter({ hasText: barber.name }).filter({ hasText: 'تفعيل اشتراك' });
    await expect(entry).toContainText('خصم الشهر الأول');
  });
});

test.describe('plans and salon page', () => {
  test('editing a plan price changes what the dialogs prefill and is audited', async ({ page }) => {
    await loginAsAdmin(page);
    await page.goto('/plans');
    const row = page.getByRole('row').filter({ hasText: 'نصف سنوي' });
    await row.getByRole('button', { name: 'تعديل' }).click();
    let dialog = page.getByRole('dialog');
    await dialog.getByLabel('السعر (د.ل)').fill('285');
    await dialog.getByRole('button', { name: 'حفظ الباقة' }).click();
    await expect(row).toContainText('285 د.ل');

    await page.goto('/subscriptions');
    await page.getByRole('button', { name: 'تفعيل اشتراك' }).click();
    await page.getByRole('dialog').getByLabel('الحلاق').selectOption({ index: 1 });
    await page.getByRole('dialog').getByRole('button', { name: 'متابعة' }).click();
    dialog = page.getByRole('dialog');
    await dialog.getByLabel('الباقة').selectOption('6');
    await expect(dialog.getByLabel('المبلغ المدفوع نقداً (د.ل)')).toHaveValue('285');
    await dialog.getByRole('button', { name: 'إلغاء' }).click();

    await page.goto('/audit');
    await page.getByRole('button', { name: 'الباقات' }).click();
    await expect(page.getByRole('button', { name: 'الباقات' })).toHaveAttribute('aria-pressed', 'true');
    await expect(page.getByRole('row').filter({ hasText: 'نصف سنوي · 285 د.ل' }).first()).toBeVisible();

    await page.goto('/plans');
    await row.getByRole('button', { name: 'تعديل' }).click();
    dialog = page.getByRole('dialog');
    await dialog.getByLabel('السعر (د.ل)').fill('280');
    await dialog.getByRole('button', { name: 'حفظ الباقة' }).click();
    await expect(row).toContainText('280 د.ل');
  });

  test('the salon page shows monthly bookings, an expired row with a call button and the legend', async ({ page }) => {
    const barber = await createPendingBarber('منتهي');
    await barber.admin.rpc('activate_subscription', { p_barber_id: barber.barberId, p_months: 1, p_amount: 50, p_note: null });
    const ended = '2026-09-28T10:00:00Z';
    expect((await barber.admin.from('barbers').update({ subscription_ends_at: ended }).eq('id', barber.barberId)).error).toBeNull();
    const { data } = await barber.admin.from('admin_barbers').select('salon_id').eq('id', barber.barberId).single();

    await loginAsAdmin(page);
    await page.goto(`/salons/${data!.salon_id}`);
    await expect(page.getByRole('columnheader', { name: 'حجوزات الشهر' })).toBeVisible();
    const row = page.getByRole('row').filter({ hasText: barber.name });
    await expect(row).toContainText('منتهي');
    await expect(row).toContainText('انتهى 28 سبتمبر');
    await expect(row.getByRole('link', { name: `اتصال بـ ${barber.name}` })).toHaveAttribute('href', `tel:+${barber.phone}`);
    await expect(row.getByRole('button', { name: 'تجديد' })).toBeVisible();
    const legend = page.getByRole('list', { name: 'دليل حالات الاشتراك' }).getByRole('listitem');
    await expect(legend).toHaveCount(3);
    await expect(legend.nth(1)).toContainText('حسابه موجود، يظهر كغير متاح للحجز حتى التجديد.');
  });
});

test.describe('customers', () => {
  test('search by phone and unblock a blocked customer', async ({ page }) => {
    const customer = await createCustomer('حظر');
    const admin = await signedIn('0910000001');
    const { error } = await admin.from('profiles').update({ no_show_count: 3, blocked_at: new Date().toISOString() }).eq('id', customer.id);
    expect(error).toBeNull();

    await loginAsAdmin(page);
    await page.goto('/customers');
    await page.getByPlaceholder('ابحث بالاسم أو رقم الهاتف').fill(customer.national);
    const row = page.getByRole('row').filter({ hasText: customer.name });
    await expect(row).toBeVisible();
    await expect(row.getByTestId('no-show-count')).toHaveText('3');
    await expect(row).toContainText('محظور');
    await row.getByRole('button', { name: 'فك الحظر' }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'فك الحظر' }).click();
    await expect(row.getByTestId('no-show-count')).toHaveText('0');
    await expect(row).not.toContainText('محظور');

    const { data } = await admin.from('profiles').select('no_show_count,blocked_at').eq('id', customer.id).single();
    expect(data).toEqual({ no_show_count: 0, blocked_at: null });
  });
});

test.describe('password reset', () => {
  test('a customer gets a one-time temporary password that works', async ({ page }) => {
    const customer = await createCustomer('كلمة');
    await loginAsAdmin(page);
    await page.goto('/customers');
    await page.getByPlaceholder('ابحث بالاسم أو رقم الهاتف').fill(customer.national);
    await page.getByRole('row').filter({ hasText: customer.name }).getByRole('button', { name: 'كلمة المرور' }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog.getByTestId('temporary-password')).toHaveCount(0);
    await dialog.getByRole('button', { name: 'إنشاء كلمة مرور مؤقتة' }).click();

    const temporary = (await dialog.getByTestId('temporary-password').textContent())!.trim();
    expect(temporary).toMatch(/^[A-Za-z0-9]{12}$/);
    await expect(dialog).toContainText('تظهر هذه الكلمة مرة واحدة فقط');
    await page.keyboard.press('Escape');
    await page.mouse.click(5, 5);
    await expect(dialog.getByTestId('temporary-password')).toHaveText(temporary);

    expect(await signInResult(customer.phone, PASSWORD)).not.toBeNull();
    expect(await signInResult(customer.phone, temporary)).toBeNull();

    await dialog.getByRole('button', { name: 'تم' }).click();
    await page.getByRole('row').filter({ hasText: customer.name }).getByRole('button', { name: 'كلمة المرور' }).click();
    await expect(page.getByRole('dialog').getByTestId('temporary-password')).toHaveCount(0);
  });

  test('a barber can be reset from the barbers page', async ({ page }) => {
    const barber = await createPendingBarber('مرور');
    await loginAsAdmin(page);
    await page.goto('/barbers?q=' + encodeURIComponent(barber.name));
    await page.getByRole('row').filter({ hasText: barber.name }).getByRole('button', { name: 'كلمة المرور' }).click();
    const dialog = page.getByRole('dialog');
    await dialog.getByRole('button', { name: 'إنشاء كلمة مرور مؤقتة' }).click();
    const temporary = (await dialog.getByTestId('temporary-password').textContent())!.trim();
    expect(await signInResult(barber.phone, temporary)).toBeNull();
  });

  test('the function refuses a caller who is not an admin', async () => {
    const customer = await createCustomer('رفض');
    const other = await createCustomer('هدف');
    const db = await signedIn(customer.phone);
    const { data } = await db.auth.getSession();
    const response = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL ?? 'http://127.0.0.1:54321'}/functions/v1/admin-reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${data.session!.access_token}`, apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH' },
      body: JSON.stringify({ profile_id: other.id }),
    });
    expect(response.status).toBe(403);
    expect(await signInResult(other.phone, PASSWORD)).toBeNull();
  });
});

test.describe('lookups and read models', () => {
  test('add, rename and delete a city and an area', async ({ page }) => {
    const city = `مدينة ${stamp()}`;
    const renamed = `${city} ب`;
    await loginAsAdmin(page);
    await page.goto('/locations');
    await page.getByLabel('اسم مدينة جديدة', { exact: true }).fill(city);
    await page.getByRole('button', { name: 'إضافة: اسم مدينة جديدة' }).click();
    await page.getByRole('button', { name: city, exact: false }).first().click();
    await page.getByLabel('اسم منطقة جديدة', { exact: true }).fill('منطقة الاختبار');
    await page.getByRole('button', { name: 'إضافة: اسم منطقة جديدة' }).click();
    await expect(page.getByText('منطقة الاختبار')).toBeVisible();

    await page.getByRole('button', { name: `تعديل ${city}` }).click();
    await page.getByLabel('الاسم').fill(renamed);
    await page.getByRole('button', { name: 'حفظ' }).click();
    await expect(page.getByText(renamed).first()).toBeVisible();

    await page.getByRole('button', { name: `حذف ${renamed}` }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'حذف' }).click();
    await expect(page.getByText(renamed)).toHaveCount(0);
  });

  test('a city used by a salon cannot be deleted', async ({ page }) => {
    await loginAsAdmin(page);
    await page.goto('/locations');
    await page.getByRole('button', { name: 'حذف طرابلس' }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'حذف' }).click();
    await expect(page.getByRole('alert').filter({ hasText: 'لا يمكن الحذف' })).toBeVisible();
    await expect(page.getByText('طرابلس').first()).toBeVisible();
  });

  test('pending barbers are sent to review and name-only barbers show no account', async ({ page }) => {
    const barber = await createPendingBarber('مراجعة');
    await loginAsAdmin(page);
    await page.goto('/barbers');
    const pending = page.getByRole('row').filter({ hasText: barber.name });
    await expect(pending.getByRole('link', { name: 'مراجعة الطلب' })).toHaveAttribute('href', '/activation');
    await expect(pending.getByRole('button', { name: 'تفعيل اشتراك' })).toHaveCount(0);
    await page.goto('/barbers?q=' + encodeURIComponent('وليد الشريف'));
    await expect(page.getByRole('row').filter({ hasText: 'وليد الشريف' })).toContainText('بلا حساب');
  });

  test('bookings switch between one day and all days', async ({ page }) => {
    await loginAsAdmin(page);
    await page.goto('/bookings');
    await expect(page.getByLabel('اليوم')).toBeVisible();
    await page.getByRole('button', { name: 'كل الأيام' }).click();
    await expect(page.getByLabel('اليوم')).toHaveCount(0);
    await page.getByRole('button', { name: 'اختيار يوم' }).click();
    await expect(page.getByLabel('اليوم')).not.toHaveValue('');
  });

  test('cancellation counts per barber come from the admin view', async ({ page }) => {
    await loginAsAdmin(page);
    await page.goto('/barbers?q=' + encodeURIComponent('علي القماطي'));
    await expect(page.getByRole('columnheader', { name: 'إلغاءات الحلاق' })).toBeVisible();
    await expect(page.getByRole('row').filter({ hasText: 'علي القماطي' })).toBeVisible();
  });
});
