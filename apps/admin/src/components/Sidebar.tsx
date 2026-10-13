'use client';

import { BarChart3, Calendar, Hourglass, Home, MapPinned, ScrollText, ShieldCheck, Store, Tags, User, Users, LogOut } from 'lucide-react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

import { useAdmin } from './AuthProvider';
import { PoleMark } from './Logo';

const ITEMS = [
  { href: '/', label: 'نظرة عامة', icon: Home },
  { href: '/activation', label: 'طلبات التفعيل', icon: Hourglass, badge: true },
  { href: '/salons', label: 'الصالونات', icon: Store },
  { href: '/barbers', label: 'الحلاقون', icon: Users },
  { href: '/subscriptions', label: 'الاشتراكات', icon: ShieldCheck },
  { href: '/bookings', label: 'الحجوزات', icon: Calendar },
  { href: '/customers', label: 'الزبائن', icon: User },
  { href: '/reports', label: 'التقارير', icon: BarChart3 },
  { href: '/plans', label: 'الباقات', icon: Tags },
  { href: '/locations', label: 'المدن والمناطق', icon: MapPinned },
  { href: '/audit', label: 'سجل الإجراءات', icon: ScrollText },
];

export function Sidebar() {
  const pathname = usePathname();
  const { counts, signOut } = useAdmin();

  return (
    <aside className="sticky top-0 flex h-screen w-[72px] shrink-0 flex-col gap-2 bg-blue-900 p-3 text-onDark lg:w-[240px] lg:p-4">
      <div className="mb-4 flex items-center justify-center gap-3 pt-2 lg:justify-start lg:px-2">
        <PoleMark />
        <div className="hidden lg:block">
          <div className="text-[20px] font-extrabold leading-6 text-white">حلّاقي</div>
          <div className="text-[12px] text-onDark">لوحة الإدارة</div>
        </div>
      </div>
      <nav aria-label="القائمة الرئيسية" className="flex flex-1 flex-col gap-1 overflow-y-auto">
        {ITEMS.map(({ href, label, icon: Icon, badge }) => {
          const active = href === '/' ? pathname === '/' : pathname.startsWith(href);
          return (
            <Link
              key={href}
              href={href}
              aria-current={active ? 'page' : undefined}
              title={label}
              className={`relative flex h-11 items-center justify-center gap-3 rounded-ctl px-3 text-[15px] font-semibold transition-colors lg:justify-start ${
                active ? 'bg-blue-800 font-bold text-red-400' : 'hover:bg-blue-800/60'
              }`}
            >
              <Icon size={20} strokeWidth={1.8} />
              <span className="sr-only lg:not-sr-only lg:flex-1">{label}</span>
              {badge && counts.pending > 0 && (
                <span aria-label={`${counts.pending} طلبات`} className="absolute end-1 top-1 flex size-5 items-center justify-center rounded-full bg-red-pole text-[11px] font-bold text-white lg:static lg:size-6 lg:text-[12px]">
                  {counts.pending}
                </span>
              )}
            </Link>
          );
        })}
      </nav>
      <button
        type="button"
        onClick={signOut}
        title="تسجيل الخروج"
        className="flex h-11 items-center justify-center gap-3 rounded-ctl px-3 text-[15px] font-semibold text-onDark-muted hover:bg-blue-800/60 lg:justify-start"
      >
        <LogOut size={20} strokeWidth={1.8} />
        <span className="sr-only lg:not-sr-only">تسجيل الخروج</span>
      </button>
    </aside>
  );
}
