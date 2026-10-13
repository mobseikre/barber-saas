import { expect, test } from '@playwright/test';

import { loginAsAdmin } from './support';

const PAGES = [
  ['01-overview', '/', 'نظرة عامة'],
  ['02-activation', '/activation', 'طلبات التفعيل'],
  ['03-salons', '/salons', 'الصالونات'],
  ['04-barbers', '/barbers', 'الحلاقون'],
  ['05-subscriptions', '/subscriptions', 'الاشتراكات'],
  ['06-bookings', '/bookings', 'الحجوزات'],
  ['07-customers', '/customers', 'الزبائن'],
  ['08-reports', '/reports', 'التقارير'],
  ['09-locations', '/locations', 'المدن والمناطق'],
  ['13-plans', '/plans', 'الباقات'],
  ['14-audit', '/audit', 'سجل الإجراءات'],
] as const;

test('every page renders in RTL with Cairo and no console errors', async ({ page }) => {
  const errors: string[] = [];
  page.on('console', (message) => message.type() === 'error' && !message.text().includes('tile.openstreetmap') && errors.push(message.text()));
  page.on('pageerror', (error) => errors.push(error.message));

  await loginAsAdmin(page);
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  for (const [file, path, title] of PAGES) {
    await page.goto(path);
    await expect(page.getByRole('heading', { name: title, level: 1 })).toBeVisible();
    await expect(page.getByRole('status', { name: 'جارٍ التحميل' })).toHaveCount(0);
    await page.waitForTimeout(600);
    await expect(page.locator('body')).toHaveCSS('font-family', /Cairo/);
    await page.screenshot({ path: `screenshots/${file}.png`, fullPage: true });
  }
  expect(errors).toEqual([]);
});

test('salon page, approval dialog and reset dialog screenshots', async ({ page }) => {
  await loginAsAdmin(page);
  await page.goto('/salons');
  await page.getByRole('row').filter({ hasText: 'صالون الأناقة' }).getByRole('link', { name: 'إدارة الحلاقين' }).click();
  await expect(page.getByRole('heading', { name: 'صالون الأناقة', level: 1 })).toBeVisible();
  await expect(page.getByRole('row').filter({ hasText: 'وليد الشريف' })).toContainText('بلا حساب');
  await page.waitForTimeout(600);
  await page.screenshot({ path: 'screenshots/10-salon-detail.png', fullPage: true });

  await page.goto('/activation');
  await page.getByRole('row').filter({ hasText: 'مراد الزنتاني' }).getByRole('button', { name: 'تفعيل وتحديد الباقة' }).click();
  await expect(page.getByTestId('salon-map')).toBeVisible();
  await page.waitForTimeout(2000);
  await page.screenshot({ path: 'screenshots/11-approve-dialog.png' });
  await page.keyboard.press('Escape');

  await page.goto('/customers');
  await page.getByRole('row').filter({ hasText: 'عبدالله الزوي' }).getByRole('button', { name: 'كلمة المرور' }).click();
  await page.screenshot({ path: 'screenshots/12-reset-dialog.png' });
});

test('salon page works with the keyboard-visible focus ring on inputs', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('كلمة المرور').focus();
  await expect(page.getByLabel('كلمة المرور')).toHaveCSS('border-color', 'rgb(255, 92, 98)');
  await page.screenshot({ path: 'screenshots/00-login.png' });
});
