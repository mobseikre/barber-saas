import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { expect, type Page } from '@playwright/test';

const URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? 'http://127.0.0.1:54321';
const KEY = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';

export const PASSWORD = 'password123';
export const ADMIN_PHONE = '0910000001';

const client = () => createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });

export const emailOf = (phone: string) => `${phone.startsWith('0') ? `218${phone.slice(1)}` : phone}@app.local`;

export async function signedIn(phone: string, password = PASSWORD): Promise<SupabaseClient> {
  const db = client();
  const { error } = await db.auth.signInWithPassword({ email: emailOf(phone), password });
  if (error) throw error;
  return db;
}

export async function signInResult(phone: string, password: string) {
  const { error } = await client().auth.signInWithPassword({ email: emailOf(phone), password });
  return error;
}

function randomPhone(): string {
  return `2189${Math.floor(Math.random() * 1e8).toString().padStart(8, '0')}`;
}

export interface Account {
  id: string;
  phone: string;
  national: string;
  name: string;
}

async function signUp(role: 'barber' | 'customer', name: string): Promise<Account & { db: SupabaseClient }> {
  const phone = randomPhone();
  const db = client();
  const { data, error } = await db.auth.signUp({ email: emailOf(phone), password: PASSWORD, options: { data: { full_name: name, phone, role } } });
  if (error || !data.user) throw error ?? new Error('sign up failed');
  return { id: data.user.id, phone, national: `0${phone.slice(3)}`, name, db };
}

export const stamp = () => Math.random().toString(36).slice(2, 7);

export async function createPendingBarber(label: string) {
  const name = `حلاق ${label} ${stamp()}`;
  const account = await signUp('barber', name);
  const admin = await signedIn(ADMIN_PHONE);
  const { data: area } = await admin.from('areas').select('id').eq('name', 'حي الأندلس').single();
  const salon = `صالون ${label} ${stamp()}`;
  const { data, error } = await account.db.rpc('register_barber', {
    p_display_name: name,
    p_salon_name: salon,
    p_area_id: area!.id,
    p_address: 'شارع الاختبار',
    p_latitude: 32.8752,
    p_longitude: 13.1146,
  });
  if (error) throw error;
  return { ...account, barberId: data.id as string, salon, admin };
}

export async function createCustomer(label: string) {
  const { id, phone, national, name } = await signUp('customer', `زبون ${label} ${stamp()}`);
  return { id, phone, national, name };
}

export async function loginAsAdmin(page: Page) {
  await page.goto('/login');
  await page.getByLabel('رقم الهاتف').fill(ADMIN_PHONE);
  await page.getByLabel('كلمة المرور').fill(PASSWORD);
  await page.getByRole('button', { name: 'تسجيل الدخول' }).click();
  await expect(page.getByRole('heading', { name: 'نظرة عامة' })).toBeVisible();
}
